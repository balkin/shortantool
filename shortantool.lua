#!/usr/bin/tarantool

box.cfg{ slab_alloc_arena = 0.1 }
space = box.space.links
if not space then
	space = box.schema.create_space('links')
	space:create_index('primary', {parts = {1, 'STR'}})
	space:create_index('urls', {parts = {2, 'STR'}})
	space:insert { 't', 'https://www.tcsbank.ru/credit/form/mgmplatinum/?master_data=c9e0a9291113e8958daf58759583f5d29369fa188dc1808f7b6a9bfbedb034bcef77bcf76ad04e92c3c8fbc94f548b8080364505c6bd236b83c2266e67e4085197fa73705f0f606877cb8dbe2d84b6e21e3350e41df4747ea80cb438d897f6f46653ee8cb16dabe333038f7d7bd893e6&utm_source=mgm_cc.mgm_cc.directlink.directlink.google_cc.search_lpd_balancetransfer.oplata_kredita&utm_campaign=direct_link&utm_medium=mgm.act&utm_content=direct_link', 0 }
	space:insert { 'ta', 'https://www.tcsbank.ru/credit/form/mgmallairlines/?master_data=c9e0a9291113e8958daf58759583f5d29369fa188dc1808f7b6a9bfbedb034bcef77bcf76ad04e92c3c8fbc94f548b8080364505c6bd236b83c2266e67e4085197fa73705f0f606877cb8dbe2d84b6e21e3350e41df4747ea80cb438d897f6f40c7fb68b6be5503b1494011cd098ac7f&utm_source=mgm_aa.mgm_cc.directlink.directlink.google_cc.search_lpd_balancetransfer.oplata_kredita&utm_campaign=direct_link&utm_medium=mgm.act&utm_content=direct_link', 0 }
	space:insert { 'bic', 'http://www.shareasale.com/r.cfm?b=369006&u=891403&m=38570&urllink=&afftrack=', 0 }
end

httpd = require('http.server').new('0.0.0.0', 8080)
log = require('log')
dump = require('dump')

function my_handler(req)
	url = space:select { req:stash('short') }
	local resp = req:render({status=200, text="OK"})
	if next(url) == nil then
		resp.text = req:stash('short') .. "\nURL NOT FOUND\n"
	else
		resp.status = 302
		resp.headers = { location = url[1][2] }
		resp.text = "REDIRECT " .. url[1][2]
	end
	return resp
end

httpd:route({ path = '/:short' }, my_handler)
httpd:start()

