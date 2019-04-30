local marshal = require 'marshal'

-- Grab the client/server code from share.lua
local cs = require 'https://raw.githubusercontent.com/castle-games/share.lua/34cc93e9e35231de2ed37933d82eb7c74edfffde/cs.lua'

-- We're not using a dedicated server yet
USE_CASTLE_CONFIG = true

--- Creates a new client that's able to connect to a server
function createNewClient()
  local shareClient = cs.client

  local client = {
    _connectCallbacks = {},
    _receiveCallbacks = {},
    _disconnectCallbacks = {},

    _handleConnect = function(self)
      for _, callback in ipairs(self._connectCallbacks) do
        callback(client)
      end
    end,
    _handleReceive = function(self, msg)
      for _, callback in ipairs(self._receiveCallbacks) do
        callback(msg)
      end
    end,
    _handleDisconnect = function(self)
      for _, callback in ipairs(self._disconnectCallbacks) do
        callback()
      end
    end,

    connect = function(self)
      if USE_CASTLE_CONFIG then
        shareClient.useCastleConfig()
      else
        shareClient.enabled = true
        shareClient.start('127.0.0.1:22122')
      end
    end,
    disconnect = function(self, reason)
      shareClient.kick()
    end,
    isConnected = function(self)
      return shareClient.connected
    end,
    send = function(self, msg)
      shareClient.send(marshal.encode(msg))
    end,
    onConnect = function(self, callback)
      table.insert(self._connectCallbacks, callback)
    end,
    onReceive = function(self, callback)
      table.insert(self._receiveCallbacks, callback)
    end,
    onDisconnect = function(self, callback)
      table.insert(self._disconnectCallbacks, callback)
    end
  }

  function shareClient.connect()
    client:_handleConnect()
  end

  function shareClient.receive(msg)
    client:_handleReceive(marshal.decode(msg))
  end

  function shareClient.disconnect()
    client:_handleDisconnect()
  end

  return client
end

-- Creates a new server that's able to listen for new client connections
function createNewServer()
  local shareServer = cs.server

  local server = {
    _clients = {},
    _connectCallbacks = {},

    _handleConnect = function(self, client)
      table.insert(self._clients, client)
      for _, callback in ipairs(self._connectCallbacks) do
        callback(client)
      end
    end,
    _handleReceive = function(self, clientId, msg)
      for _, client in ipairs(self._clients) do
        if client.clientId == clientId then
          client:_handleReceive(msg)
          break
        end
      end
    end,
    _handleDisconnect = function(self, clientId)
      for _, client in ipairs(self._clients) do
        if client.clientId == clientId then
          client:_handleDisconnect()
          break
        end
      end
    end,
    _send = function(self, clientId, msg)
      shareServer.sendExt(clientId, nil, nil, marshal.encode(msg))
    end,
    _disconnect = function(self, clientId, reason)
      shareServer.kick(clientId)
    end,

    startListening = function(self)
      if USE_CASTLE_CONFIG then
        shareServer.useCastleConfig()
      else
        shareServer.enabled = true
        shareServer.start('22122')
      end
    end,
    stopListening = function(self)
      -- TODO
    end,
    isListening = function(self)
      return server.started
    end,
    getClients = function(self)
      return self._clients
    end,
    onConnect = function(self, callback)
      table.insert(self._connectCallbacks, callback)
    end
  }

  function shareServer.connect(clientId)
    local client = createServerSideClient(clientId, server)
    server:_handleConnect(client)
  end

  function shareServer.receive(clientId, msg)
    server:_handleReceive(clientId, marshal.decode(msg))
  end

  function shareServer.disconnect(clientId)
    server:_handleDisconnect(clientId)
  end

  return server
end

-- Creates a client on the server-side that's able to communicate with it's corresponding client-side client
function createServerSideClient(clientId, server)
  return {
    _server = server,
    _isConnected = true,
    _receiveCallbacks = {},
    _disconnectCallbacks = {},

    _handleReceive = function(self, msg)
      for _, callback in ipairs(self._receiveCallbacks) do
        callback(msg)
      end
    end,
    _handleDisconnect = function(self)
      self._isConnected = false
      for _, callback in ipairs(self._disconnectCallbacks) do
        callback()
      end
    end,

    clientId = clientId,
    disconnect = function(self, reason)
      self._server:_disconnect(self.clientId, reason)
    end,
    isConnected = function(self)
      return self._isConnected
    end,
    send = function(self, msg)
      self._server:_send(self.clientId, msg)
    end,
    onReceive = function(self, callback)
      table.insert(self._receiveCallbacks, callback)
    end,
    onDisconnect = function(self, callback)
      table.insert(self._disconnectCallbacks, callback)
    end
  }
end

-- Create a server and a client
local server = createNewServer()
local client = createNewClient()

-- Set it up so the server and client will send a couple messages to one another
server:onConnect(function(client)
  print('SERVER: A new client connected!')
  -- Disconnect when the server receives a message from the client
  client:onReceive(function(msg)
    print('SERVER: Received message from client "' .. msg.someText .. '" [' .. msg.someNumber .. ']')
    -- Send a response to the client
    print('SERVER: Sending response')
    client:send({ someText = 'I love you too client!', someNumber = 2 })
  end)
  client:onDisconnect(function(reason)
    print('SERVER: Client disconnected "' .. (reason or 'No reason given') .. '"')
  end)
end)
client:onConnect(function()
  print('CLIENT: Connected to the server!')
  -- Send a message right when the client connects
  print('CLIENT: Sending first message')
  client:send({ someText = 'I love you server!', someNumber = 1 })
end)
client:onReceive(function(msg)
  print('CLIENT: Received message from server "' .. msg.someText .. '" [' .. msg.someNumber .. ']')
  -- Disconnect from the server
  client:disconnect('We cannot be together server!')
end)
client:onDisconnect(function(reason)
  print('CLIENT: Disconnected "' .. (reason or 'No reason given') .. '"')
end)

-- Kick everything off by starting the server and getting the client to connect to it
function cs.server.load()
  server:startListening()
end
function cs.client.load()
  client:connect()
end

local doIt = love.update
function love.update(dt)
  doIt(dt)
end
