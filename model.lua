local prednet = {}

require 'nn'
require 'nngraph'

-- included local packages
local RNN = require 'RNN'

--[[

                 Rl+1[t]
                   |
                   |
                   V
               +-------+
               |       |
    Rl[t-1]--->| Rl[t] |<---El[t-1]
               |       |
               +-------+     +-------------------------------+
                   |         |        Block (Layer: l)       |
                   |         |        ================       |
                   |         |    +------+                   |
                   |         |    | ^    |                   |
                   +------------->| A[t] |--+                |
              Rl[t]          |    |      |  |                |
                             |    +------+  |    +------+    |
                             |              +--->|      |    |
                             |                   | E[t] |---------->El[t]
                             |              +--->|      |    |
                             |    +------+  |    +------+    |
                             |    |      |  |                |
        Img/El-1[t]-------------->| A[t] |--+                |
                             |    |      |                   |
                             |    +------+                   |
                             |                               |
                             +-------------------------------+

--]]

function prednet:__init(opt)
   -- Input/Output channels for A of every layer
   self.channels = torch.Tensor({{  1,   1},
                                 {  2,  32},
                                 { 64,  64},
                                 {128, 128},
                                 {256, 256}})
   self.layers = opt.layers
   self.seq = opt.seq
   self.res = opt.res
end

-- Macros
local SC = nn.SpatialConvolution

local function block(l, L, iChannel, oChannel)
   local inputs = {}
   local outputs = {}

   --[[
       Input and outputs of ONE BLOCK
       Inputs: Image   -> A1 / El-1    -> Al
               Rl      -> Rl
               Total = 2

      Outputs: El
               Ah for layer 1
               Total = 1/2
   --]]

   -- Create input and output containers for nngraph gModule for ONE block
   table.insert(inputs, nn.Identity()())         -- A1 / El-1
   table.insert(inputs, nn.Identity()())         -- Rl

   table.insert(outputs, nn.Identity()())        -- El

   local A
   local layer = tostring(l)
   if l == 1 then
      A = inputs[1]:annotate{name = 'A' .. layer, graphAttributes = {
                            style = 'filled',
                            fillcolor = 'skyblue'}}
   else
      local nodeA = nn.Sequential()
      A = (inputs[1]
           - nodeA:add(SC(iChannel, oChannel, 3, 3, 1, 1, 1, 1))
                  :add(nn.ReLU())
                  :add(nn.SpatialMaxPooling(2, 2, 2, 2)))
                  :annotate{name = 'A' .. layer, graphAttributes = {
                            style = 'filled',
                            fillcolor = 'skyblue'}}
   end

   -- Get Rl
   local R = inputs[2]

   -- Predicted A
   local nodeAh = nn.Sequential()
   local Ah = (R:annotate{name = 'R' .. layer, graphAttributes = {
                          style = 'filled',
                          fillcolor = 'springgreen'}}
               - nodeAh:add(SC(2*oChannel, oChannel, 3, 3, 1, 1, 1, 1))
                       :add(nn.ReLU()))
                       :annotate{name = 'Ah' .. layer, graphAttributes = {
                                 color = 'blue',
                                 fontcolor = 'blue'}}

   -- Error between A and A hat
   local E = ({{A, Ah} - nn.CSubTable(1) - nn.ReLU(),
              {Ah, A} - nn.CSubTable(1) - nn.ReLU()}
             - nn.JoinTable(1))
               :annotate{name = 'E' .. layer, graphAttributes = {
                         style = 'filled',
                         fillcolor = 'lightpink'}}

   -- This El will be used by Al+1
   outputs[1] = E

   -- TODO Ah1 ignored for now
   -- if l == 1 then
   --    -- For first layer return Ah for viewing
   --    table.insert(outputs, nn.Identity()())
   --    outputs[2] = Ah
   -- end

   return nn.gModule(inputs, outputs)
end

function prednet:getModel()
   --[[
       L -> Total number of layers
       Input and outputs in time series
       Inputs: Image   -> A1
               Rl[t-1] -> Rl
               El[t-1] -> Rl
               RL+1    -> RL        This is always set to ZERO
               Total = 2L+2

      Outputs: Ah1, Rl, El
               Total = 2L+1
   --]]

   local inputs = {}
   local outputs = {}

   local L = self.layers
   local seq = self.seq

   -- Create input and output containers for nngraph gModule for TIME SERIES
   for i = 1, (2*L+1) do
      table.insert(inputs, nn.Identity()())
      table.insert(outputs, nn.Identity()())
   end
   table.insert(inputs, nn.Identity()())

--------------------------------------------------------------------------------
-- Get Rl
--------------------------------------------------------------------------------
   local Rl_1Channel = 2*self.channels[L+1][2]
   local iChannel    = self.channels[L][1]
   local oChannel    = self.channels[L][2]
   -- Calculate Rl+1 -> Rl -> Rl-1
   outputs[2*L] = ({inputs[2*(L+1)], inputs[2*L], inputs[2*L+1]}
                  - RNN.getModel(2*oChannel, Rl_1Channel))
                   :annotate{name = 'R' .. tostring(L), graphAttributes = {
                             color = 'blue',
                             fontcolor = 'blue'}}
   for l = L-1, 1, -1 do
      Rl_1Channel = 2*self.channels[l+1][2]
      iChannel    = self.channels[l][1]
      oChannel    = self.channels[l][2]
      -- Input for R:             Rl+1,     Rl[t-1],       El[t-1]
      outputs[2*l] = ({outputs[2*(l+1)], inputs[2*l], inputs[2*l+1]}
                     - RNN.getModel(2*oChannel, Rl_1Channel))
                      :annotate{name = 'R' .. tostring(l), graphAttributes = {
                                color = 'blue',
                                fontcolor = 'blue'}}
   end

--------------------------------------------------------------------------------
-- Stack blocks to form the model for time t
--------------------------------------------------------------------------------
   -- XXX
   outputs[1] = inputs[1]
   for l = 1, L do
      iChannel = self.channels[l][1]
      oChannel = self.channels[l][2]

      local A

      -- TODO
      -- if l == 1 then                     -- img,       Rl
      --    {outputs[2*l+1], outputs[1]} = {inputs[1], outputs[2*l]}
      --                                   - block(l, L, iChannel, oChannel)
      -- else                 -- El-1,             Rl
         outputs[2*l+1] = ({outputs[2*l-1], outputs[2*l]}
                          - block(l, L, iChannel, oChannel))
                           :annotate{name = 'Block' .. tostring(l), graphAttributes = {
                                     style = 'filled',
                                     fillcolor = 'lightpink'}}
      -- end
   end

   return nn.gModule(inputs, outputs)
end

return prednet
