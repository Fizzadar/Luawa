-- source: http://blog.jrtycoons.com/index.php/2012/08/an-nginx-smtp-client-in-lua/
-- w/ minor edits to get it working?

-- SMTP client using ngx_lua non-blocking sockets
-- Copyright (C) 2012 Pete Mueller (clubpetey)
-- Tycoon Ventures, LLC
--[[
Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
]]

local base = _G;
local math = require("math");
local tcp = ngx.socket.tcp;
local class = smtp;
local mt = { __index = class };
local CRLF = "\r\n";
local strlen = string.len;
local setmetatable = setmetatable
local string = string
local table = table
local ngx = ngx

module(...);

_VERSION = '0.10';

-- default server used to send e-mails
SERVER = "localhost"
-- default port
PORT = 25
-- domain used in HELO command and default sendmail
IDENT = "localhost"
-- default time zone (means we don't know)
ZONE = "-0000"
-- mailer identifier
MAILER = "nginx smtp " .. _VERSION;
-- email list separator
EMAIL_SEP = ",";
-- default content type
DEFAULT_CONTENT = 'text/plain; charset="iso-8859-1"';

--
-- helpers (local functions) --
--

-- convert table keys to lowercase
local function lower_table(t)
    local lower = {}
    for i,v in base.pairs(t or lower) do
        lower[string.lower(i)] = v
    end
    return lower
end

-- find the email address
-- if there is no "<>" then the whole string is the email address
-- othewise, extract the "<>" part

local function find_email(em)
    s, e = em:find("<.*>");
    if (s == nil) then return "<" .. em .. ">" end;
    return em:sub(s,e);
end

local seqno = 0;

-- return a pseduo-unique boundry identifier
function get_boundry()
    seqno = seqno + 1
    return string.format('%015u==%05d==%05u', ngx.time(), math.random(0, 99999), seqno);
end;

-- add emails to the rcpt table, and convert the table
-- of emails to a string if necessary
local function add_rcpt(emails, rcpt)
  rcpt = rcpt or {};
  if (base.type(emails) == "table") then
    for i,v in base.ipairs(emails) do
      add_rcpt(v, rcpt);
    end
    return table.concat(emails, EMAIL_SEP);
  elseif (base.type(emails) == "string") then
    table.insert(rcpt, find_email(emails));
    return emails;
  end
  return nil;
end

-- get the next line from the given socket
-- and check it matches the given pattern
local function check_resp(sock, v)
    local line, err = sock:receive();
    if not line then
      return nil, "recv error: " .. (err or "");
    end
    if not string.find(line, v) then
      return nil, "server response: " .. line;
    end
    return true;
end

-- send the command to the socket
-- if "verify" is present, check that the response matches
-- the given pattern, return error string if failure
local function send_cmd(sock, cmd, verify)
  local bytes, err = sock:send(cmd)
  if not bytes then
      return  nil, "send error: " .. (err or "")
  end
  if not verify then return true end;
  return check_resp(sock, verify);
end

local send_data = send_cmd;

-- send headers to socket
local function send_headers(sock, h)
  h = h or {};
  h['content-type'] = h['content-type'] or DEFAULT_CONTENT;

  for k,v in base.pairs(h) do
    send_data(sock, {k, ": ", v, CRLF});
  end
  send_data(sock, CRLF);
  return true;
end

-- return true if string "s" starts with prefix "p"
local function starts_with(s, p)
  if p ~= nil then
    if p  == string.sub(s, 1, strlen(p)) then
      return true;
    end
  end

  return false;
end

-- public functions

function new(self)
  local sock, err = tcp();
  if not sock then
      return nil, err;
  end;
  local newmt = self
  newmt.sock = sock
  return setmetatable(newmt, mt);
end


function set_timeout(self, timeout)
  local sock = self.sock;
  if not sock then return nil, "not initialized" end;

  return sock:settimeout(timeout)
end

-- build out a multipart "part" based on content and mimetype
-- this is for TEXT parts only
function build_part(c, mt)
  local part = {headers = {}, content = c};
  part.headers['content-type'] = mt or DEFAULT_CONTENT;
  return part;
end


-- build out a multipart "part" for an attachement
-- opt is a table with ftype (attachement type) fdate (file mod date)
-- and fname (original filename)
function build_attachment(data, mt, opt)
  local part = {headers = {}};
  part.headers['content-type'] = mt or DEFAULT_CONTENT;
  -- valid options are "inline" or "attachment"
  opt.ftype = opt.ftype or "attachment";

  -- this is the file's modification date
  opt.fdate = opt.fdate or ngx.http_time(ngx.time());
  disp = opt.ftype .. '; modification-date="' .. opt.fdate .. '"';

  -- some mail systems use "filenmae" others "name", we set both
  if (opt.fname ~= nil) then
    disp = disp .. "; filename=" .. opt.fname .. "; name=" .. opt.fname;
  end
  part.headers['content-disposition'] = disp;

  -- base64 encode the data
  part.headers['content-transfer-encoding'] = "base64";
  part.content = ngx.encode_base64(data);
  return part;
end


function send(self, msg)
    local sock = self.sock;
    if not sock then return nil, "not initialized" end;

    -- check if username, then need password
    local greeting = "HELO";
    if (msg.username ~= nil) then
      if (not msg.password) then
        return nil, "username without password";
      end
      greeting = "EHLO";
    end

    -- lower case all header
    local headers = lower_table(msg.headers)

    -- add the necessary ones
    headers["date"] = headers["date"] or
        ngx.http_time(ngx.time()) .. (msg.tzone or ZONE);
    headers["x-mailer"] = headers["x-mailer"] or MAILER;

    -- this can't be overriden
    headers["mime-version"] = "1.0"

    local from = headers["from"];
    if (from == nil) then return nil, "no send specified" end;
    from = find_email(from);

    -- for each of to, cc, and bcc, add the emails (either a string or a table of strings)
    -- then remove the BCC header
    local rcpt = {}
    headers["to"] = add_rcpt(headers["to"], rcpt);
    headers["cc"] = add_rcpt(headers["cc"], rcpt);
    add_rcpt(headers["bcc"], rcpt);
    headers["bcc"] = nil;

    -- CONNECT
    local ok, err = sock:connect(msg.server or SERVER, msg.port or PORT);
    if (not ok) then return nil, "connect error: " .. (err or "") end;

    -- identify ourselves
    local ok, err = check_resp(sock, "2..");
    if (not ok) then return nil, err end;

    local ok, err = send_cmd(sock, {greeting, " ", msg.ident or IDENT, CRLF}, "2..");
    if (not ok) then return nil, err end;

    local auth = nil;
    -- authentication (if necessary)

    if (greeting == "EHLO") then
      while true do
        local line, err = sock:receive();
        if not line then break end;
        if (line:find("AUTH[^\n]+LOGIN")) then auth = "LOGIN" end;
        if (line:find("AUTH[^\n]+PLAIN") and not auth) then auth = "PLAIN" end;
        if (starts_with(line, "250 ")) then break end;
      end

      if not auth then
        return nil, "no authentication available";
      end

      if (auth == "LOGIN") then
        local ok, err = send_cmd(sock, {"AUTH LOGIN", CRLF}, "3..");
        if (not ok) then return nil, err end;

        local ok, err = send_cmd(sock, {ngx.encode_base64(msg.username), CRLF}, "3..");
        if (not ok) then return nil, err end;

        local ok, err = send_cmd(sock, {ngx.encode_base64(msg.password), CRLF}, "3..");
        if (not ok) then return nil, err end;
      elseif (auth == "PLAIN") then
        local auth = ngx.encode_base64("\0" .. user .. "\0" .. password);
        local ok, err = send_cmd(sock, {"AUTH PLAIN ", auth, CRLF}, "2..");
        if (not ok) then return nil, err end;
      end
    end

    -- MAIL FROM
    local ok, err = send_cmd(sock, {"MAIL FROM: ", from, CRLF}, "2..");
    if (not ok) then return nil, err end;

    -- RCPT TO
    for i,v in base.ipairs(rcpt) do
      local ok, err = send_cmd(sock, {"RCPT TO: ", v, CRLF}, "2..");
      if (not ok) then return nil, err end;
    end

    -- DATA
    local ok, err = send_cmd(sock, {"DATA", CRLF}, "3..");
    if (not ok) then return nil, err end;

    local body = msg.body
    local multipart = false;

    -- simple email, body is a string
    if (base.type(body) == "string") then
      headers['content-type'] = headers['content-type'] or DEFAULT_CONTENT;
    end

  if (base.type(body) == "table") then
    -- special shortcut for the common text + html email
    -- if body is a table and has a "plain" and "html" value, we use multipart/alternative
    if ((body.html ~= nil) and (body.plain ~= nil)) then
      headers['content-type'] = "multipart/alternative";
      body.content = {build_part(body.plain), build_part(body.html, "text/html")};
      body.html = nil;
      body.plain = nil;
    end

    -- if body.content exists, then we use multipart/mixed
    -- the content should be a list of tables with a headers and content values
    -- this include the "alternative" shortcut above
    if (body.content ~= nil) then
      body.boundry = get_boundry();
      headers['content-type'] = headers['content-type'] or 'multipart/mixed';
      headers['content-type'] = headers['content-type'] .. '; boundary="' ..  body.boundry .. '"';
      multipart = true;
    else
    -- otherwise we are a table of strings and use "text/plain"
      headers['content-type'] = headers['content-type'] or DEFAULT_CONTENT;
    end
  end

    -- dump headers
    send_headers(sock, headers);

    if not multipart then
      send_data(sock, body);
    else
      if body.preamble then
        send_data(sock, body.preamble);
        send_data(sock, CRLF);
      end

      for i, m in base.ipairs(body.content) do
          send_data(sock, {"\r\n--", body.boundry, "\r\n"});
          send_headers(sock, m.headers);
          send_data(sock, m.content);
      end
      -- last boundry
      send_data(sock, {"\r\n--", body.boundry, "\r\n\r\n"});

      if body.epilogue then
        send_data(sock, body.epilogue);
        --send_data(sock, CRLF);
      end
    end

    -- close out
    local ok, err = send_cmd(sock, "\r\n.\r\n", "2..");
    if (not ok) then return nil, err end;

    -- QUIT
    local ok, err = send_cmd(sock, {"QUIT",  CRLF}, "2..");
    if (not ok) then return nil, err end;

    sock:close();
    return true;
end

