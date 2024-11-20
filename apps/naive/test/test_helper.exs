ExUnit.start()

Application.ensure_all_started(:mox)

Mox.defmock(Test.BinanceMock, for: BinanceMock)
Mox.defmock(Test.Naive.LeaderMock, for: Naive.Leader)
