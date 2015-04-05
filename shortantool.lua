#!/usr/bin/tarantool

box.cfg{ slab_alloc_arena = 0.1 }
space = box.space.links
if not space then
	space = box.schema.create_space('links')
	space:create_index('primary', { parts = {1, 'STR'} })
	space:create_index('urls', { parts = {3, 'STR'} })
	space:insert { 't', 0, 'https://www.tcsbank.ru/credit/form/mgmplatinum/?master_data=c9e0a9291113e8958daf58759583f5d29369fa188dc1808f7b6a9bfbedb034bcef77bcf76ad04e92c3c8fbc94f548b8080364505c6bd236b83c2266e67e4085197fa73705f0f606877cb8dbe2d84b6e21e3350e41df4747ea80cb438d897f6f46653ee8cb16dabe333038f7d7bd893e6&utm_source=mgm_cc.mgm_cc.directlink.directlink.google_cc.search_lpd_balancetransfer.oplata_kredita&utm_campaign=direct_link&utm_medium=mgm.act&utm_content=direct_link' }
	space:insert { 'ta', 0, 'https://www.tcsbank.ru/credit/form/mgmallairlines/?master_data=c9e0a9291113e8958daf58759583f5d29369fa188dc1808f7b6a9bfbedb034bcef77bcf76ad04e92c3c8fbc94f548b8080364505c6bd236b83c2266e67e4085197fa73705f0f606877cb8dbe2d84b6e21e3350e41df4747ea80cb438d897f6f40c7fb68b6be5503b1494011cd098ac7f&utm_source=mgm_aa.mgm_cc.directlink.directlink.google_cc.search_lpd_balancetransfer.oplata_kredita&utm_campaign=direct_link&utm_medium=mgm.act&utm_content=direct_link' }
	space:insert { 'bic', 0, 'http://www.shareasale.com/r.cfm?b=369006&u=891403&m=38570&urllink=&afftrack=' }
end

-- Number to string conversion table. I made "-" equal to zero, it's not going to be very frequent. 
-- Also, shortened URL will never start with "-"
local charactermappings = {
	["a"] = 1,  ["b"] = 2,  ["c"] = 3,  ["d"] = 4,  ["e"] = 5,  ["f"] = 6,  ["g"] = 7,  ["h"] = 8,  ["i"] = 9,  ["j"] = 10,
	["k"] = 11, ["m"] = 12, ["n"] = 13, ["o"] = 14, ["p"] = 15, ["q"] = 16, ["r"] = 17, ["s"] = 18, ["t"] = 19, ["u"] = 20,
	["v"] = 21, ["w"] = 22, ["x"] = 23, ["y"] = 24, ["z"] = 25, ["A"] = 26, ["B"] = 27, ["C"] = 28, ["D"] = 29, ["E"] = 30,
	["F"] = 31, ["G"] = 32, ["H"] = 33, ["J"] = 34, ["K"] = 35, ["L"] = 36, ["M"] = 37, ["N"] = 38, ["P"] = 39, ["Q"] = 40,
	["R"] = 41, ["S"] = 42, ["T"] = 43, ["U"] = 44, ["V"] = 45, ["W"] = 46, ["X"] = 47, ["Y"] = 48, ["Z"] = 49, ["0"] = 50,
	["1"] = 51, ["2"] = 52, ["3"] = 53, ["4"] = 54, ["5"] = 55, ["6"] = 56, ["7"] = 57, ["8"] = 58, ["9"] = 59, ["-"] = 0
}
local numbermappings = { }
local totalmappings = 59
for k, v in pairs(charactermappings) do numbermappings[v] = k end

-- Convert short string to number. shorttonumeric("Hi") == 1956. 
-- charactermappings["i"] + charactermappings["H"] * 59 = 9+33*59 = 1956
local function shorttonumeric(str)
	local v = 0
	local m = 1
	for k in str:reverse():gmatch(".") do
		v = v + charactermappings[k] * m
		m = m * totalmappings
	end
	return v
end

-- Convert a number to short string. numerictoshort(1956) == "Hi"
-- 1956 % 59 = 9, (1956-9)/59 = 33; 9 is i, 33 is H.
local function numerictoshort(num)
	-- Zero and small numbers can be converted easily
	if num <= totalmappings then
		return numbermappings[num]
	end
	local s = ""
	-- Divide by 59 until the number becomes small
	repeat
		local r = num % totalmappings
		s = numbermappings[r] .. s
		num = (num - r) / totalmappings
	until num <= totalmappings
	-- small number is converted easily
	return numbermappings[num] .. s
end

-- Code borrowed from https://github.com/golgote/lua-resty-info/blob/master/lib/resty/info.lua
local function htmlspecialchars(str)
	local html = {
		["<"] = "&lt;",
		[">"] = "&gt;",
		["&"] = "&amp;",
	}
	return string.gsub(tostring(str), "[<>&]", function(char)
		return html[char] or char
	end)
end

log = require('log')
dump = require('dump')

function shortener_handler(req)
	local url = req:param('url')
	if url then
		local previous = space.index.urls:select( url )
		if next(previous) == nil then
			log.info("Shortening " .. url)
		else
			return req:render({text=previous[1][1]})
		end
	end
	local resp = req:render({text="Required parameter missing: url"})
	resp.status = 400
	return resp
end

function shortcut_handler(req)
	local ss = req:stash('short')
	local resp
	local url = space:select { ss }
	if next(url) == nil then
		log.warn("Cannot find redirect to " .. ss )
		resp = req:render({status=404, text = "404"})
		resp.status = 404
	else
		local u = url[1][3]
		local cnt = space:inc( ss )
		log.info("Redirecting to " .. u .. " ::: " .. cnt)
		resp = req:render({text = [[<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<html>
<head>
<script type="text/javascript">
<!--
location.replace(']] .. u .. [[');
//-->
</script>
<noscript>
<meta http-equiv="refresh" content="0; url=]] .. u .. [[">
</noscript>
</head>
<body>
<a href="]] .. u .. '">' .. u .. [[</a>.
</body>
</html>]] })
		resp.status = 302
		resp.headers = { location = u }
	end
	return resp
end

-- log.info (shorttonumeric("Hi"))
-- log.info (numerictoshort(1956))

httpd = require('http.server').new('0.0.0.0', 8080)
httpd:route({ path = '/:short' }, shortcut_handler)
httpd:route({ path = '/api/shortener' }, shortener_handler)
httpd:start()

