import Config

config :naive,
  binance_client: Test.BinanceMock,
  repo: Test.Naive.RepoMock

config :core,
  pubsub_client: Test.PubSubMock,
  logger: Test.LoggerMock
