import Config

config :naive,
  binance_client: Test.BinanceMock,
  leader: Test.Naive.LeaderMock
