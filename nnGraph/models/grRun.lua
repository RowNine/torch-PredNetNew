require 'convGRU'
require 'nngraph'

torch.setdefaulttensortype('torch.FloatTensor')
nngraph.setDebug(true)

--inDim, outDim, kw, kh, stride, pad, #Layer, dropout
numLayer = 2
m = lstm(1,3,7,7,1,3,numLayer,0.5)

--Cell and hidden layer number should be same
x = torch.Tensor(1,32,32)
h = torch.Tensor(3,32,32)

ht = {}
for i =1, numLayer do
   table.insert(ht,h:cuda())
end
i = {x:cuda(),unpack(ht)}
--i = {x:cuda(),h:cuda()}

print(i)
m:cuda()
o = m:forward(i)
print(o)
