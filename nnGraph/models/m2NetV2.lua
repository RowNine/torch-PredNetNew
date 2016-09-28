-- Eugenio Culurciello
-- August 2016
-- MatchNet: a model of PredNet from: https://arxiv.org/abs/1605.08104
-- Chainer implementation conversion based on: https://github.com/quadjr/PredNet/blob/master/net.py

require 'nn'
require 'nngraph'
require 'models.convLSTM'
local c = require 'trepl.colorize'
backend = nn

function mNet(nlayers,input_stride,poolsize,channels,clOpt)
local layer={}
-- P = prediction branch, A_hat in paper
-- This module creates the MatchNet network model, defined as:
-- inputs = {prevE, thisE, nextR}
-- outputs = {E , R}, E == discriminator output, R == generator output
local Mp = backend.SpatialMaxPooling(poolsize, poolsize, poolsize, poolsize)
local up = nn.SpatialUpSamplingNearest(poolsize)
local Re = nn.ReLU()

-- creating input and output lists:
local inputs = {}
local outputs = {}
--This is because No Err in the first Layer
inputs[1] = nn.Identity()() -- x input
for L = 1, nlayers do
   inputs[3*(L-1)+2] = nn.Identity()() -- previous E
   inputs[3*(L-1)+3] = nn.Identity()() -- previous Cell
   inputs[3*(L-1)+4] = nn.Identity()() -- previous Hidden
end

--Create instance of lstm
local convlstm = {}
for L = nlayers, 1, -1 do
   if L == nlayers then
      convlstm[L] = lstm(channels[L]*2,clOpt.cellCh[L],clOpt)
   else
      convlstm[L] = lstm(clOpt.lstmCh[L],clOpt.cellCh[L],clOpt)
   end
end

--Top Down
local outLstm = {}
for L = nlayers, 1 , -1 do
   if L == nlayers then
      outLstm[L] = {inputs[3*(L-1)+2],inputs[3*(L-1)+3],inputs[3*(L-1)+4]} - convlstm[L]
   else
      upR = outLstm[L+1] - nn.SelectTable(2) - up
      --Conv channels is 1 step forward since it starts from 1
      --Fill up input of LSTM channels
      inR = {upR,inputs[3*(L-1)+2]} - nn.JoinTable(1)
      outLstm[L] = {inR, inputs[3*(L-1)+3],inputs[3*(L-1)+4]} - convlstm[L]
   end
   outputs[3*(L-1)+3] = outLstm[L] - nn.SelectTable(1)
   outputs[3*(L-1)+4] = outLstm[L] - nn.SelectTable(2)
end
--Down Up
E = {}
local cA, Ah
local pE, A, upR
for L = 1, nlayers do
   print('Creating layer:', L)

   -- define layer functions:
   if L == 1 then
      Ah = backend.SpatialConvolution(clOpt.cellCh[L], 1,3, 3, input_stride, input_stride, 1, 1) -- P convolution
   else
      Ah = backend.SpatialConvolution(clOpt.cellCh[L], channels[L], 3, 3, input_stride, input_stride, 1, 1) -- P convolution
   end


   if L == 1 then
      x = inputs[1]
   else
      --pE previous layer E
      pE = outputs[3*(L-2)+2]
      cA = backend.SpatialConvolution(clOpt.cellCh[L],channels[L], 3, 3, input_stride, input_stride, 1, 1) -- A convolution, maxpooling
      A = pE - cA - Re - Mp
      pE:annotate{graphAttributes = {color = 'green', fontcolor = 'green'}}
   end
   --iR is already updated so we do second forloop
   print('I am in Down Top ',L)
   iR = outLstm[L] - nn.SelectTable(2)
   iR:annotate{graphAttributes = {color = 'blue', fontcolor = 'green'}}
   local P = iR - Ah - nn.ReLU()
   if L == 1 then
      outputs[1] = iR - Ah - nn.ReLU() -- this layer E
      EN = {x, P} - nn.CSubTable(1)   -- PReLU instead of +/-ReLU
      EP = {P, x} - nn.CSubTable(1)   -- PReLU instead of +/-ReLU
      outputs[3*(L-1)+2] = {EN, EP} - nn.JoinTable(1)  -- this layer E
   else
      EN = {A, P} - nn.CSubTable(1) -- PReLU instead of +/-ReLU
      EN:annotate{graphAttributes = {color = 'red', fontcolor = 'green'}}
      EP = {P, A} - nn.CSubTable(1) -- PReLU instead of +/-ReLU
      EP:annotate{graphAttributes = {color = 'red', fontcolor = 'blue'}}
      E[L]  = {EN, EP} - nn.JoinTable(1)
      E[L]:annotate{graphAttributes = {color = 'blue', fontcolor = 'blue'}}
      outputs[3*(L-1)+2] = E[L]-- this layer E
   end
   -- set outputs:
end
return nn.gModule(inputs, outputs)

end
