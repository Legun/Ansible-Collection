server {
 listen 446 ssl http2 deferred;
 # listen [::]:446 ssl http2;

	ssl_certificate /etc/ssl/certs/beta.jetcrypto.pem;
	ssl_certificate_key /etc/ssl/private/beta.jetcrypto.key;

	root /var/www/html/jetcrypto;

	# Add index.php to the list if you are using PHP
	index  index.html index.php index.htm ;

	server_name jetcrypto.com ;

	# pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
	#
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/run/php/php7.0-fpm.sock;
	}

	# Allow Let's encrypt webroot cert renewal
	location ~ /.well-known {

		allow all;
	}

	# Protect resources starting with dot .htaccess .svn .ssh etc
	location ~ /\. {

		deny all;
		return 404;
	}

	# Prevent clients from accessing to backup/config/source files
	location ~* (?:\.(?:bak|conf|dist|fla|in[ci]|log|psd|sh|sql|sw[op])|~)$ {

		deny all;
	}

	# don't send the nginx version number in error pages and Server header
	server_tokens off;

	location / {
	
		allow 94.141.187.194; # Office
		allow 144.76.155.58; # Jenkins
#		deny all; # drop rest of the world

		# Security
		#add_header X-Frame-Options SAMEORIGIN;
		#add_header Content-Security-Policy "default-src 'self' https://*.gstatic.com https://*.googleapis.com 'unsafe-inline';" always;
		#add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
		#add_header X-XSS-Protection "1; mode=block";

		# Server push (experimental)
		add_header Link "</bootstrap.css>; rel=preload; as=style";
		add_header Link "</style.css>; rel=preload; as=style";

		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		try_files $uri $uri/ =404;
    }	


	# Access to special pages restriction by ip
	location ~* /(metadata|swagger) {
	

		allow 94.141.187.194; # Office
		allow 144.76.155.58; # Jenkins
		allow 77.108.115.0/24; # Bank
#		deny all; # drop rest of the world
		proxy_pass http://127.0.0.1:2001;
		proxy_http_version 1.1;
		proxy_set_header Upgrade $http_upgrade;
		proxy_set_header Connection keep-alive;
		proxy_set_header Host $host;
		proxy_cache_bypass $http_upgrade;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}

	# Pass non-static content to backend
	location ~* /(api|avatar|qr) {

		allow 94.141.187.194; # Office
		allow 144.76.155.58; # Jenkins
#		deny all; # drop rest of the world
		proxy_pass http://127.0.0.1:2001;
		proxy_http_version 1.1;
		proxy_set_header Upgrade $http_upgrade;
		proxy_set_header Connection keep-alive;
		proxy_set_header Host $host;
		proxy_cache_bypass $http_upgrade;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

#		proxy_cache my_cache;

		add_header X-Frame-Options SAMEORIGIN;
		add_header X-XSS-Protection "1; mode=block";
		
    }
	 location ~* /(api|update) {
         proxy_pass http://127.0.0.1:2001;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection keep-alive;
                proxy_set_header Host $host;
                proxy_cache_bypass $http_upgrade;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

#                proxy_cache my_cache;
		add_header Access-Control-Allow-Origin *;

                add_header X-Frame-Options SAMEORIGIN;
                add_header X-XSS-Protection "1; mode=block";

                add_header Debug-Cache-Status $upstream_cache_status; # For debugging!
		#For download content
		add_header Content-Disposition "attachment";
		add_header Content-Type "application/force-download";
		add_header Content-Type "application/octet-stream";
    }
    
	# Browser caching

	# No cache for service worker
	location = /service-worker.js {
    expires off;
	access_log off;
    add_header Cache-Control "no-cache, no-store, must-revalidate";
}

	# Cache local static content in browser (short living)
	location ~* \.(?:css|js|json)$ {

		expires 7d;
		access_log off;
		add_header Cache-Control "public";
	}

	# Cache local static content in browser (long living)
	location ~* \.(?:jpg|jpeg|gif|png|ico|svg|svgz|ttf|ttc|otf|eot|woff|woff2)$ {

		expires 1M; # One month
		access_log off;
		add_header Cache-Control "public";
	}

}
