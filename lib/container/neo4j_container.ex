defmodule Testcontainers.Neo4jContainer do
  alias Testcontainers.ContainerBuilder
  alias Testcontainers.Container
  alias Testcontainers.LogWaitStrategy
  alias Testcontainers.Neo4jContainer

  @default_image "neo4j"
  @default_tag "5.16.0"
  @default_image_with_tag "#{@default_image}:#{@default_tag}"
  @default_bolt_port 7687
  @default_http_port 7474
  @default_username "neo4j"
  @default_password "your_neo4j_password"

  defstruct [:image, :wait_timeout, :username, :bolt_port, :http_port, :password, :apoc]

  def new,
    do: %__MODULE__{
      image: @default_image_with_tag,
      wait_timeout: 60_000,
      bolt_port: @default_bolt_port,
      http_port: @default_http_port,
      password: @default_password,
      username: @default_username,
      apoc: false
    }

  def with_image(%__MODULE__{} = config, image) when is_binary(image) do
    %{config | image: image}
  end

  def with_apoc(%__MODULE__{} = config, apoc) when is_boolean(apoc) do
    %{config | apoc: apoc}
  end

  def default_image, do: @default_image

  def default_bolt_port, do: @default_bolt_port

  def default_http_port, do: @default_http_port

  def get_password, do: @default_password

  def get_username, do: @default_username

  def bolt_port(%Container{} = container) do
    Container.mapped_port(container, @default_bolt_port)
  end

  def http_port(%Container{} = container) do
    Container.mapped_port(container, @default_http_port)
  end

  def bolt_uri(%Container{} = container) do
    "bolt://#{Testcontainers.get_host()}:#{bolt_port(container)}"
  end

  def http_uri(%Container{} = container) do
    "http://#{Testcontainers.get_host()}:#{http_port(container)}"
  end

  defimpl ContainerBuilder do
    import Container

    @impl true
    @spec build(%Neo4jContainer{}) :: %Container{}
    def build(%Neo4jContainer{} = config) do
      if not String.starts_with?(config.image, Neo4jContainer.default_image()) do
        raise ArgumentError,
          message:
            "Image #{config.image} is not compatible with #{Neo4jContainer.default_image()}"
      end

      container =
        new(config.image)
        |> with_exposed_port(Neo4jContainer.default_bolt_port())
        |> with_exposed_port(Neo4jContainer.default_http_port())
        |> with_environment(:NEO4J_AUTH, "#{config.username}/#{config.password}")
        |> with_waiting_strategy(LogWaitStrategy.new(~r/Started\./, config.wait_timeout))

      if config.apoc do
        container
        |> with_environment(NEO4J_PLUGINS, "'[\"apoc\"]'")
        |> with_environment(:NEO4J_dbms_security_procedures_unrestricted, "apoc.*")
        |> with_environment(:NEO4J_dbms_security_procedures_whitelist, "apoc.*")
      else
        container
      end
    end

    @impl true
    @spec is_starting(%Neo4jContainer{}, %Container{}, %Tesla.Env{}) :: :ok
    def is_starting(_config, _container, _conn), do: :ok
  end
end
