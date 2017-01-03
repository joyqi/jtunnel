
Opt = require 'optimist'
Crypto = require 'crypto'
Net = require 'net'

argv = Opt
    .usage 'Usage: $0 [ -l 80 ] [ -h 123.123.123.123:80 ] [ -c rc4 ]'
    .boolean 'd'
    .boolean 'c'
    .alias 'l', 'listen'
    .alias 'h', 'host'
    .alias 'r', 'crypto'
    .alias 'p', 'password'
    .alias 'd', 'dump'
    .alias 'c', 'client'
    .string 'l'
    .string 'h'
    .default 'r', 'rc4'
    .default 'c', false
    .default 'p', '123456'
    .describe 'l', 'host and port jtunnel listen on'
    .describe 'h', 'host and port of the backend host'
    .describe 'r', 'encryption method'
    .describe 'p', 'encryption cipher key'
    .describe 'd', 'dump all encryption method'
    .describe 'c', 'client mode'
    .argv

if argv.d
    ciphers = Crypto.getCiphers()
    console.log ciphers.join '  '
    process.exit 0
else
    Opt.demand ['l', 'h']
        .argv

listen = if 0 <= argv.listen.indexOf ':' then argv.listen.split ':' else [null, argv.listen]
host = if 0 <= argv.host.indexOf ':' then argv.host.split ':' else [null, argv.host]

# create server
server = Net.createServer {allowHalfOpen : yes, pauseOnConnect: yes}, (s) ->
    console.log "input connect: #{s.remoteAddress}@#{s.remotePort}"

    cipher = Crypto.createCipher argv.crypto, argv.password
    decipher = Crypto.createDecipher argv.crypto, argv.password
     
    target = Net.connect host[1], host[0], ->
        console.log "output connect: #{target.localAddress}@#{target.localPort}"
        
        s.pipe if argv.client then cipher else decipher
         .pipe target
         .pipe if argv.client then decipher else cipher
         .pipe s

        s.resume()

    s.on 'close', ->
        console.log "input close: #{s.remoteAddress}@#{s.remotePort}"

    s.on 'error', (error) ->
        console.log "input error: #{error.message}"
        s.destroy() if s? and not s.destroyed
        target.destroy() if target? and not target.destroyed
    
    target.on 'close', ->
        console.log "output close"

    target.on 'error', (error) ->
        console.log "output error: #{error.message}"
        s.destroy() if s? and not s.destroyed
        target.destroy() if target? and not target.destroyed


server.on 'error', (error) ->
    console.error error


server.on 'listening', ->
    console.log "listening at #{argv.listen}"
    console.log (if argv.client then 'client' else 'server') + ' mode'
    console.log "using encryption method #{argv.crypto} with secret #{argv.password}"


# listen server
server.listen listen[1], listen[0]

