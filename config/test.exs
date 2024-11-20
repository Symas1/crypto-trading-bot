import Config

config :naive,
  binance_client: Test.BinanceMock,
  leader: Test.Naive.LeaderMock

config :core,
  pubsub_client: Test.PubSubMock,
  logger: Test.LoggerMock
