const http   = require('http');
const server = http.createServer((req, res) => {
	const initial_path = req.url || '';
	const path         = initial_path.replace("/api/v2/", "/api/");
	const referer      = req.headers.referer || '';
	let domain         = referer.match(/^(?i:http?s:\/\/)?(.+)\.working_example\.ai.*/);
	if (!domain) {
		const state_encoded = require('url').parse(req.url, true).query.state.toString();
		if (state_encoded) {
			const state_decoded = Buffer.from(state_encoded, 'base64').toString('utf-8');
			const state_json    = JSON.parse(state_decoded);
			if (state_json && state_json.env_name) {
				domain = [null, state_json.env_name];
			}
		}
	}
	const prefix          = domain ? domain[1] : '';
	const redirect_domain = "https://" + prefix + ".working-example.com";
	const redirect_url    = redirect_domain + path;
	let output            = {
		'req':       {
			'url':         req.url,
			'headers':     req.headers,
			'method':      req.method,
			'httpVersion': req.httpVersion,
			'socket':      {
				'remoteAddress': req.socket.remoteAddress,
				'remotePort':    req.socket.remotePort
			}
		},
		'res':       {
			'statusCode':    res.statusCode,
			'statusMessage': res.statusMessage
		},
		'processed': {
			'redirect': redirect_url,
			'path':     path,
			'referer':  referer,
			'domain':   domain ? domain[1] : 'default'
		}
	};
	console.log(JSON.stringify(output, null, 2));
	let headers = {
		'Location':                         redirect_url,
		'Access-Control-Allow-Origin':      redirect_domain,
		'Access-Control-Allow-Credentials': 'true',
		'Access-Control-Allow-Methods':     '*',
		'Access-Control-Allow-Headers':     '*',
		'Referrer-Policy':                  'unsafe-url',
		'Origin':                           req.headers.origin,
		'Referer':                          req.headers.referer
	};
	if (req.headers.authorization) {
		headers.Authorization = req.headers.authorization;
	}
	const returned_headers = new Headers(headers);
	res.statusCode         = 307;
	res.setHeaders(returned_headers);
	res.end('Redirecting to ' + redirect_url);
});
server.listen(3333, () => {
	console.log('Server running on port 3333');
});