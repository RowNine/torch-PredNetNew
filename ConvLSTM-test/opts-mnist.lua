opt = {}
-- general options:
opt.dir     = 'outputs_mnist_line' -- subdirectory to save experiments in
opt.seed    = 1250         -- initial random seed

-- Model parameters:
opt.nlayers = 2 -- number of layers of MatchNet
opt.inputSizeW = 64   -- width of each input patch or image
opt.inputSizeH = 64   -- width of each input patch or image
opt.eta       = 1e-4 -- learning rate
opt.etaDecay  = 1e-5 -- learning rate decay
opt.momentum  = 0.9  -- gradient momentum
opt.maxIter   = 30000 --max number of updates
opt.nSeq      = 19
opt.nFilters  = {1,32,32,32} --9,45} -- number of filters in the encoding/decoding layers
opt.nFiltersMemory   = {32,32}--45} --{45,60}
opt.kernelSize       = 7 -- size of kernels in encoder/decoder layers
opt.kernelSizeMemory = 7
opt.padding   = torch.floor(opt.kernelSize/2) -- pad input before convolutions
opt.gradClip = 50
opt.stride = 1 --opt.kernelSizeMemory -- no overlap
opt.poolsize = 2 -- maxpooling size
opt.constrWeight = {0,1,0.001}

opt.dataFile = 'data-small-train.t7'
opt.dataFileTest = 'data-small-test.t7'
opt.modelFile = nil
opt.configFile = nil
opt.statInterval = 50 -- interval for printing error
opt.v            = false  -- be verbose
opt.display      = true -- display stuff
opt.displayInterval = opt.statInterval
opt.save         = true -- save models
opt.saveInterval = 10000

if not paths.dirp(opt.dir) then
   os.execute('mkdir -p ' .. opt.dir)
end
