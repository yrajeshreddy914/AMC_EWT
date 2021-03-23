function frames = getNNFrames(rx,modType)
%getNNFrames Generate formatted frames for neural networks
%   F = getNNFrames(X,MODTYPE) formats the input X, into frames
%   that can be used with the neural network designed in this
%   example, and returns the frames in the output F.

frames = helperModClassFrameGenerator(rx,1024,1024,32,8);
frameStore = helperModClassFrameStore(10,1024,categorical({modType}));
add(frameStore,frames,modType);
frames = get(frameStore);
end