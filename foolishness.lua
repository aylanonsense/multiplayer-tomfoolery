--- Creates a new client that's able to connect to a server
function createNewClient()
  return {
    connect = function(self) end,
    disconnect = function(self, reason) end,
    isConnected = function(self) end,
    send = function(self, msg) end,
    onConnect = function(self, callback) end,
    onReceive = function(self, callback) end,
    onDisconnect = function(self, callback) end
  }
end

-- Creates a new server that's able to listen for new client connections
function createNewServer()
  return {
    startListening = function(self) end,
    stopListening = function(self) end,
    isListening = function(self) end,
    getClients = function(self) end,
    onConnect = function(self, callback) end,
    onDisconnect = function(self, callback) end
  }
end

-- Creates a client on the server-side that's able to communicate with it's corresponding client-side client
function createServerSideClient()
  return {
    disconnect = function(self, reason) end,
    isConnected = function(self) end,
    send = function(self, event, params) end,
    onReceive = function(self, callback) end,
    onDisconnect = function(self, callback) end
  }
end

-- Create a server and a client
local server = createNewServer()
local client = createNewClient()

-- Set it up so the server and client will send a couple messages to one another
server:onConnect(function(client)
  print('SERVER: A new client connected!')
  -- Send a message right when the client connects
  print('SERVER: Sending first message')
  client:send({ someText = 'I love you client!', someNumber = 1 })
  -- Disconnect when the server receives a message from the client
  client:onReceive(function(msg)
    print('SERVER: Received message from client "' .. msg.someText .. '" [' .. msg.someNumber .. ']')
    client:disconnect('We cannot be together client!')
  end)
end)
client:onConnect(function()
  print('CLIENT: Connected to the server!')
end)
client:onReceive(function(msg)
  print('CLIENT: Received message from server "' .. msg.someText .. '" [' .. msg.someNumber .. ']')
  -- Send a response to the server
  client:send({ someText = 'I love you too server!', someNumber = 2 })
end)
client:onDisconnect(function(reason)
  print('CLIENT: Disconnected from server "' .. reason .. '"')
end)

-- Kick everything off by starting the server and getting the client to connect to it
server:startListening()
client:connect()
