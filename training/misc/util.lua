function computMatric(targetC, targetF, output)
   local criterion = nn.MSECriterion()
   local cerr = criterion:forward(targetC:squeeze(),output[1]:squeeze())
   local ferr = criterion:forward(targetF:squeeze(),output[1]:squeeze())
   local batch = targetC :size(1)
   return cerr, ferr
end
function writLog(cerr,ferr,loss,logger)
   print(string.format('cerr : %.4f ferr: %.4f loss: %.2f',cerr, ferr, loss))
   logger:add{
      ['cerr'] = cerr,
      ['ferr']  = ferr,
      ['loss'] = loss
   }
end
function shipGPU(table)
   for i,item in pairs(table) do
      table[i] = item:cuda()
   end
end
function prepareData(opt, sample)
   if opt.useGPU then
      require 'cunn'
      require 'cutorch'
   end
   -- reset initial network state:
   local inTableG0 = {}
   local batch = opt.batch
   for L=1, opt.nlayers do
      if opt.batch > 1 then
         table.insert( inTableG0, torch.zeros(batch,2*opt.nFilters[L], opt.inputSizeW/2^(L-1), opt.inputSizeW/2^(L-1)) ) -- E(t-1)
         table.insert( inTableG0, torch.zeros(batch,opt.nFilters[L], opt.inputSizeW/2^(L-1), opt.inputSizeW/2^(L-1))) -- C(t-1)
         table.insert( inTableG0, torch.zeros(batch,opt.nFilters[L], opt.inputSizeW/2^(L-1), opt.inputSizeW/2^(L-1))) -- H(t-1)
      else
         table.insert( inTableG0, torch.zeros(2*opt.nFilters[L], opt.inputSizeW/2^(L-1), opt.inputSizeW/2^(L-1)) ) -- E(t-1)
         table.insert( inTableG0, torch.zeros(opt.nFilters[L], opt.inputSizeW/2^(L-1), opt.inputSizeW/2^(L-1))) -- C(t-1)
         table.insert( inTableG0, torch.zeros(opt.nFilters[L], opt.inputSizeW/2^(L-1), opt.inputSizeW/2^(L-1))) -- H(t-1)
      end
   end
   -- get input video sequence data:
   seqTable = {} -- stores the input video sequence
   data = sample[1]
   local range, flag
   if opt.batch > 1 then
      range = data:size(2)
      flag = 2
   else
      range = data:size(1)
      flag = 1
   end
   for i = 1, range do
      table.insert(seqTable, data:select(flag,i)) -- use CPU
   end
   --Ship to GPU
   if opt.useGPU then
      shipGPU(inTableG0)
      shipGPU(seqTable)
   end
   -- prepare table of states and input:
   table.insert(inTableG0, seqTable)
   -- Target
   targetC, targetF = torch.Tensor(), torch.Tensor()
   if opt.batch == 1 then
      targetF:resizeAs(data[1]):copy(data[data:size(1)])
      targetC:resizeAs(data[1]):copy(data[data:size(1)-1])
   else
      targetF:resizeAs(data[{{},data:size(2),{},{}}]):copy(data[{{},data:size(2),{},{}}])
      targetC:resizeAs(data[{{},data:size(2)-1,{},{}}]):copy(data[{{},data:size(2)-1,{},{}}])
   end
   if opt.useGPU then
      targetF = targetF:cuda()
      targetC = targetC:cuda()
      data    = data:cuda()
   end
   return inTableG0, targetC, targetF
end
function display(opt, seqTable,targetF,targetC,output)
   if opt.display and opt.batch == 1 then
      require 'env'
      local pic = { seqTable[#seqTable-3]:squeeze(),
                    seqTable[#seqTable-2]:squeeze(),
                    targetC:squeeze(),
                    targetF:squeeze(),
                    output:squeeze() }
      _im1_ = image.display{image=pic, min=0, max=1, win = _im1_, nrow = 7,
                         legend = 't-3, t-2, t-1, Target, Prediction'}
   end
end
function savePics(opt,target,output,epoch,t)
   --Save pics
   print('Save pics!')
   if math.fmod(t, opt.picFreq) == 0 and opt.batch == 1 then
      image.save(paths.concat(opt.savedir ,'pic_target_'..epoch..'_'..t..'.jpg'), target)
      image.save(paths.concat(opt.savedir ,'pic_output_'..epoch..'_'..t..'.jpg'), output)
   end
end
function save( model, optimState, opt, epoch)
   --Save models
   if opt.save  then
      print('Save models!')
      if opt.multySave then
         torch.save(paths.concat(opt.savedir ,'model_' .. epoch .. '.net'), model)
         torch.save(paths.concat(opt.savedir ,'optimState_' .. epoch .. '.t7'), optimState)
         torch.save(paths.concat(opt.savedir ,'opt' .. epoch .. '.t7'), opt)
      else
         torch.save(paths.concat(opt.savedir ,'model.net'), model)
         torch.save(paths.concat(opt.savedir ,'optimState.t7'), optimState)
         torch.save(paths.concat(opt.savedir ,'opt.t7'), opt)
      end
   end
end
