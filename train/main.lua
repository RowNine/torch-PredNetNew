-- Main function
--
-- Abhishek Chaurasia
--------------------------------------------------------------------------------

require 'nn'
require 'nngraph'
require 'optim'

torch.setdefaulttensortype('torch.FloatTensor')

-- Gather all the arguments
local opts = require 'opts'
local opt = opts.parse(arg)

if opt.dev == 'cuda' then
   require 'cunn'
   require 'cudnn'
   require 'cutorch'
   cutorch.setDevice(opt.devID)
end

torch.manualSeed(opt.seed)

local train = require 'train'
local test  = require 'test'

-- Input/Output channels for A of every layer
opt.channels = torch.ones(opt.layers + 2)
for l = 2, opt.layers + 2 do
   opt.channels[l] = 2^(l+3)
end
-- {1|3, 32, 64, 128, 256, 512}

-- Sequence and resolution information of data
-- is added to 'opt' during this initialization.
-- It also call the model generator and returns
-- the model prototype
local prototype = train:__init(opt)
test:__init(opt)

-- Logger
if not paths.dirp(opt.save) then paths.mkdir(opt.save) end
local logger, testlogger
logger = optim.Logger(paths.concat(opt.save,'error.log'))
logger:setNames{'Train prd. error', 'Train rpl. error'} -- training prediction/replica
logger:style{'+-', '+-'}
logger:display(opt.display)
testlogger = optim.Logger(paths.concat(opt.save,'testerror.log'))
testlogger:setNames{'Test prd. error', 'Test rpl. error'} -- testing prd/rpl
testlogger:style{'+-', '+-'}
testlogger:display(opt.display)

print("\nTRAINING\n")
local prevTrainError = 10000

for epoch = 1, opt.nEpochs do
   print("Epoch: ", epoch)
   local predError, replicaError = train:updateModel()
   local tpredError, treplicaError = test:updateModel(train.model)

   logger:add{predError, replicaError}
   logger:plot()

   testlogger:add{tpredError, treplicaError}
   testlogger:plot()

   -- Save the trained model
   if treplicaError > tpredError then
      print('Save !')
      local saveLocation = paths.concat(opt.save, 'model-' .. epoch .. '.net')
      prototype:float():clearState()
      torch.save(saveLocation, prototype)
      if opt.dev == 'cuda' then train.model:cuda() end
      prevTrainError = tpredError
   end
end
