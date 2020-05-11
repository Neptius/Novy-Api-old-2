defmodule NovyApiWeb.UserService do
  import Ecto.Query

  alias Ecto.Changeset

  alias NovyApiWeb.Randomizer
  alias NovyApi.Repo
  alias NovyApi.{User, AuthProvider, AuthUser, AuthProviderSession}

  @doc false
  def init_auth(label) do
    with %AuthProvider{:auth_provider_configs => auth_provider_configs} = auth_provider <-
           AuthProvider.get_by(%{:label => label}, [:auth_provider_configs]),
         auth_params = format_auth_params(auth_provider_configs),
         {:ok, %AuthProviderSession{:state => state}} <-
           create_auth_url(auth_provider, auth_params),
         {:ok, raw_url} <- format_auth_url(auth_provider, auth_params, state),
         {:ok, url} <- check_auth_url(raw_url) do
      {:ok, url}
    else
      {:error, error} ->
        {:error, error}
      _ ->
        {:error, "Provider invalide ou non configuré"}
    end
  end

  @doc false
  defp format_auth_params(auth_provider_configs) do
    Enum.reduce(
      auth_provider_configs,
      %{},
      fn %{:key => key, :value => value}, acc ->
        Map.put(acc, key, value)
      end
    )
  end

  @doc false
  defp create_auth_url(auth_provider, auth_params) do
    state = Randomizer.randomizer(32)

    auth_provider
    |> Ecto.build_assoc(:auth_provider_sessions, %{
      state: state,
      verify: false,
      scope: auth_params["scope"]
    })
    |> Repo.insert()
  end

  @doc false
  defp format_auth_url(%{:method => "oauth2"}, auth_params, state) do
    query =
      URI.encode_query(%{
        "client_id" => auth_params["client_id"],
        "redirect_uri" => auth_params["redirect_uri"],
        "response_type" => auth_params["response_type"],
        "state" => state,
        "scope" => auth_params["scope"],
        "force_verify" => true
      })

    {:ok, "#{auth_params["authorize"]}?" <> query}
  end

  @doc false
  defp format_auth_url(%{:method => "openid"}, auth_params, state) do
    query =
      URI.encode_query(%{
        "openid.ns" => auth_params["openid.ns"],
        "openid.mode" => "checkid_setup",
        "openid.claimed_id" => auth_params["openid.claimed_id"],
        "openid.identity" => auth_params["openid.identity"],
        "openid.return_to" => auth_params["openid.return_to"],
        "state" => state
      })

    {:ok, "#{auth_params["login"]}?" <> query}
  end

  @doc false
  defp format_auth_url(_auth_provider, _auth_params, _state) do
    {:error, "Méthode Invalide"}
  end

  @doc false
  defp check_auth_url(url) do
    case URI.parse(url) do
      %URI{host: nil} -> {:error, "Url Invalide"}
      _ -> {:ok, url}
    end
  end

  @doc false
  def login(%{provider: provider} = params) do
    with {:ok, auth_provider_session} <- verify_state(params),
         %AuthProvider{:auth_provider_configs => auth_provider_configs} = auth_provider <-
           AuthProvider.get_by(%{:label => provider}, [:auth_provider_configs]),
         auth_params <- format_auth_params(auth_provider_configs),
         {:ok, authorization_params} <- verify_auth_user(auth_provider, params, auth_params),
         {:ok, user_raw_data} <-
           get_user_data(auth_params, auth_provider, authorization_params, params),
         user_data = format_user_data(user_raw_data, auth_params),
         {:ok, user} = create_or_update_auth_user(user_data, auth_provider) do
      {:ok, user, auth_provider_session}
    else
      {:error, error} ->
        {:error, error}

      _ ->
        {:error, "Erreur lors de l'authentification"}
    end
  end

  @doc false
  def verify_state(%{state: state, provider: provider, scope: scope}) do
    query =
      from(aps in AuthProviderSession,
        join: ap in AuthProvider,
        on: aps.auth_provider_id == ap.id,
        where: ap.label == ^provider,
        where: aps.state == ^state,
        where: aps.verify == false,
        where: aps.scope == ^scope,
        preload: [:auth_provider]
      )

    with %AuthProviderSession{verify: false} = auth_provider_session <- Repo.one(query),
         {:ok, verified_auth_provider_session} <-
           AuthProviderSession.update_one(auth_provider_session, %{:verify => true}) do
      {:ok, verified_auth_provider_session}
    else
      {:error, error} ->
        {:error, error}

      _ ->
        {:error, "State Invalide"}
    end
  end

  @doc false
  defp verify_auth_user(%{:method => "oauth2"}, %{:code => code}, auth_params) do
    request_body =
      URI.encode_query(%{
        "client_id" => auth_params["client_id"],
        "client_secret" => auth_params["client_secret"],
        "grant_type" => "authorization_code",
        "code" => code,
        "redirect_uri" => auth_params["redirect_uri"],
        "scope" => auth_params["scope"]
      })

    options = %{
      "Content-Type" => "application/x-www-form-urlencoded"
    }

    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
           HTTPoison.post(auth_params["token"], request_body, options),
         {:ok, decoded} <- Poison.decode(body) do
      {:ok, decoded}
    else
      _ ->
        {:error, "Error: verify_auth_user"}
    end
  end

  @doc false
  defp verify_auth_user(%{:method => "openid"}, params, %{"login" => url}) do
    query =
      params
      |> Enum.filter(fn {key, _value} -> String.starts_with?(Atom.to_string(key), "openid_") end)
      |> Enum.into(%{})
      |> Enum.reduce(
        %{},
        fn {key, value}, acc ->
          Map.put(acc, String.replace(Atom.to_string(key), "openid_", "openid."), value)
        end
      )
      |> Map.put("openid.mode", "check_authentication")
      |> URI.encode_query()

    case HTTPoison.get("#{url}?" <> query) do
      {:ok, %HTTPoison.Response{body: body, status_code: 200}} ->
        {:ok, String.contains?(body, "is_valid:true\n")}

      _ ->
        {:ok, false}
    end
  end

  @doc false
  defp verify_auth_user(_provider, _params, _auth_params) do
    {:error, "Méthode Invalide"}
  end

  @doc false
  defp get_user_data(
         %{"user" => url},
         %{:method => "oauth2"},
         %{"access_token" => token},
         _params
       ) do
    headers = [Authorization: "Bearer #{token}", Accept: "Application/json; Charset=utf-8"]
    options = [ssl: [{:versions, [:"tlsv1.2"]}], recv_timeout: 500]

    with {:ok, %HTTPoison.Response{status_code: 200, body: body}} <-
           HTTPoison.get(url, headers, options),
         {:ok, decoded} <- Poison.decode(body) do
      {:ok, decoded}
    else
      error ->
        {:error, error}

      _ ->
        {:error, "Erreur: get_user_data oauth2"}
    end
  end

  @doc false
  defp get_user_data(
         %{"key" => key, "user" => user, "user_id" => user_id},
         %{:method => "openid"},
         true,
         %{:openid_claimed_id => claimed_id}
       ) do
    url =
      user
      |> String.replace("%ID%", String.replace(claimed_id, user_id, ""))
      |> String.replace("%KEY%", key)

    with {:ok, %HTTPoison.Response{body: body}} <- HTTPoison.get(url),
         {:ok, decoded} <- Poison.decode(body) do
      {:ok, decoded}
    else
      error ->
        {:error, error}

      _ ->
        {:error, "Erreur: get_user_data openid"}
    end
  end

  @doc false
  defp get_user_data(_auth_provider, _auth_params, _token, _params) do
    {:error, "Url utilisateur non valide"}
  end

  @doc false
  defp format_user_data(
         raw_user_data,
         %{
           "user_path" => user_path,
           "user_pseudo_path" => user_pseudo_path,
           "user_id_path" => user_id_path,
           "user_img_path" => user_img_path,
           "user_img_url" => user_img_url
         }
       ) do
    user_data =
      case user_path do
        user_path when user_path == nil or user_path == "" ->
          raw_user_data

        _ ->
          Elixpath.get!(raw_user_data, user_path)
      end

    auth_provider_user_img =
      case user_img_url do
        user_img_url when user_img_url == nil or user_img_url == "" ->
          user_data[user_img_path]

        _ ->
          user_img_url
          |> String.replace("{{ID}}", user_data[user_id_path])
          |> String.replace("{{AVATAR}}", user_data[user_img_path])
      end

    %{
      "auth_provider_user_id" => user_data[user_id_path],
      "auth_provider_user_pseudo" => user_data[user_pseudo_path],
      "auth_provider_user_img" => auth_provider_user_img,
      "user_data" => user_data
    }
  end

  @doc false
  defp create_or_update_auth_user(auth_user_format_data, %{:label => label} = auth_provider) do
    query =
      from(a in AuthUser,
        join: a_p in AuthProvider,
        on: a.auth_provider_id == a_p.id,
        where: a_p.label == ^label,
        where: a.auth_provider_user_id == ^auth_user_format_data["auth_provider_user_id"],
        preload: [:user, :auth_provider]
      )

    case Repo.one(query) do
      nil ->
        auth_user_changeset =
          %AuthUser{
            :auth_provider_user_id => auth_user_format_data["auth_provider_user_id"],
            :auth_provider_user_pseudo => auth_user_format_data["auth_provider_user_pseudo"],
            :auth_provider_user_img => auth_user_format_data["auth_provider_user_img"],
            :user_data => auth_user_format_data["user_data"]
          }
          |> AuthUser.changeset()
          |> Changeset.put_assoc(:user, %User{
            pseudo: auth_user_format_data["auth_provider_user_pseudo"]
          })
          |> Changeset.put_assoc(:auth_provider, auth_provider)

        with {:ok, auth_user} <- Repo.insert(auth_user_changeset),
             %AuthUser{user: user} <- Repo.preload(auth_user, [:user]),
             changeset <- User.changeset(user, %{auth_user_default_id: auth_user.id}),
             {:ok, _} <- Repo.update(changeset),
             %User{} = updated_user <-
               Repo.get(User, user.id) |> Repo.preload([:auth_user_default, :auth_users]) do
          {:ok, updated_user}
        else
          {:error, error} ->
            {:error, error}

          _ ->
            {:error, "Erreur: Création de l'utilisateur"}
        end

      auth_user ->
        params = %{
          :user_data => auth_user_format_data["user_data"],
          :auth_provider_user_pseudo => auth_user_format_data["auth_provider_user_pseudo"],
          :auth_provider_user_img => auth_user_format_data["auth_provider_user_img"]
        }

        with changeset <- AuthUser.changeset(auth_user, params),
             {:ok, _} <- Repo.update(changeset),
             %User{} = updated_user <-
               Repo.get(User, auth_user.user_id)
               |> Repo.preload([:auth_user_default, :auth_users]) do
          {:ok, updated_user}
        else
          {:error, error} ->
            {:error, error}

          _ ->
            {:error, "Erreur lors de la récupération de l'utilisateur"}
        end
    end
  end

  def create_session(user, auth_provider_session) do
    {:ok, token, _claims} =
      NovyApiWeb.Guardian.encode_and_sign(user, %{}, token_type: :access, ttl: {7, :minutes})

    {:ok, refresh_token, _claims} =
      NovyApiWeb.Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {30, :minutes})

    auth_provider_session_changeset =
      auth_provider_session
      |> Repo.preload([:user])
      |> AuthProviderSession.change_one(%{:token => token, :refresh_token => refresh_token})
      |> Changeset.put_assoc(:user, user)

    case Repo.update(auth_provider_session_changeset) do
      {:ok, updated_auth_provider_session} ->
        {:ok, updated_auth_provider_session}

      {:error, error} ->
        {:error, error}

      _ ->
        {:error, "Erreur lors de l'authentification"}
    end
  end

  def session_by_token(token) do
    AuthProviderSession
    |> where(token: ^token)
    |> preload([{:user, [:auth_user_default]}])
    |> Repo.one()
    |> case do
      session -> {:ok, session}
      nil -> {:error, "invalid authorization token"}
    end
  end
end
