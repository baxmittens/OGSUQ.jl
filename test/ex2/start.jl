using OGSUQ

ogsuqparams = OGSUQParams("StochasticOGSModelParams.xml", "SampleMethodParams.xml")
ogsuqasg = OGSUQ.init(ogsuqparams)
OGSUQ.start!(ogsuqasg)