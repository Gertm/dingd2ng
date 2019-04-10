import irc, asyncdispatch, strutils
import htmltitle, unicode
import streams
import logging
import docopt

var L = newFileLogger("dingd1ng.log", fmtStr = verboseFmtStr)

addHandler(L)

let doc = """
dingd2ng IRC Bot. 
Defaults to chat.freenode.net with nick dingd2ng.
You need to specify the channels it needs to join.
Remember to use quotes for channels: d"#channel"

Usage:
  dingd2ng [options] <channels>...

Options:
  --help                   Show this text.
  --version                Show version.
  --server=<servername>    Connect to specific server.
  --nick=<nickname>        Use specific nickname.
  --pw-file=<pw_filename>  Use server password from file.
  --post-connect=<cmds>    Post-connect IRC commands.
"""

let args = docopt(doc, version = "dingd2ng v0.2")

var nickname = "dingd2ng"
var server = "chat.freenode.net"
var channels : seq[string] = @[]
var pass = ""
var connect_cmds : seq[string] = @[]

if args["--server"]:
  server = $args["--server"]
if args["<channels>"]:
  for chan in @(args["<channels>"]):
    channels.add($chan)
if args["--nick"]:
  nickname = $args["--nick"]
if args["--pw-file"]:
  var fs = open($args["--pw-file"], fmRead)
  pass = fs.readLine()
  fs.close()
if args["--post-connect"]:
  connect_cmds = splitLines($args["--post-connect"])

echo("Password is: " & pass)

echo("***********************************************************************")
echo("** Connecting to IRC on server: ", server, " with nickname ", nickname,
     " in channels: ", channels)
echo("***********************************************************************")
     
proc onIrcEvent(client: AsyncIrc, event: IrcEvent) {.async.} =
  try:
    case event.typ
    of EvConnected:
      for cmd in connect_cmds:
        await client.send(cmd)
    of EvDisconnected, EvTimeout:
      await client.reconnect()
    of EvMsg:
      if event.cmd == MPrivMsg:
        var msg = event.params[event.params.len-1]
        if msg == "!lag":
          await client.privmsg(event.origin, formatFloat(client.getLag))
        if unicode.toLower(msg).contains("http"):
          for part in msg.split(' '):
            if unicode.toLower(part).startsWith("http"):
              let title = htmltitle.readTitle(part)
              if title.len() != 0:
                await client.privmsg(event.origin, title)
        if unicode.tolower(msg).startsWith("!say"):
          await client.privmsg(event.origin, "You just said it.")
      echo(event.raw)
  except:
    let
      e = getCurrentException()
      msg = getCurrentExceptionMsg()
    error("Got exception ", repr(e), " with message ", msg)

var client = newAsyncIrc(
  server,
  nick=nickname,
  user="dingd2ng",
  realname="dingd2ng",
  serverPass=nickname & ":" & pass,
  joinChans=channels,
  callback=onIrcEvent,
)
asyncCheck client.run()

runForever()
