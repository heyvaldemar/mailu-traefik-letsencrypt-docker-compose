# Mailu with Let's Encrypt Using Docker Compose

📙 The complete installation guide is available on my [website](https://www.heyvaldemar.com/install-mailu-using-docker-compose/).

❗ Change variables in the `.env` to meet your requirements.

To generate a 128-bit security key for the `SECRET_KEY` variable, use the following OpenSSL command:

`openssl rand -hex 16`

💡 Note that the `.env` file should be in the same directory as `mailu-traefik-letsencrypt-docker-compose.yml`.

Create networks for your services before deploying the configuration using the commands:

`docker network create traefik-network`

Deploy Mailu using Docker Compose:

`docker compose -f mailu-traefik-letsencrypt-docker-compose.yml -p mailu up -d`

# Administrator Account

Set password for administrator account. Replace `PASSWORD` with a strong, secure password:

`docker compose -p mailu exec admin flask mailu admin admin yourdomain.com PASSWORD`

# Author

I’m Vladimir Mikhalev, the [Docker Captain](https://www.docker.com/captains/vladimir-mikhalev/), but my friends can call me Valdemar.

🌐 My [website](https://www.heyvaldemar.com/) with detailed IT guides\
🎬 Follow me on [YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1)\
🐦 Follow me on [Twitter](https://twitter.com/heyValdemar)\
🎨 Follow me on [Instagram](https://www.instagram.com/heyvaldemar/)\
🧵 Follow me on [Threads](https://www.threads.net/@heyvaldemar)\
🐘 Follow me on [Mastodon](https://mastodon.social/@heyvaldemar)\
🧊 Follow me on [Bluesky](https://bsky.app/profile/heyvaldemar.bsky.social)\
🎸 Follow me on [Facebook](https://www.facebook.com/heyValdemarFB/)\
🎥 Follow me on [TikTok](https://www.tiktok.com/@heyvaldemar)\
💻 Follow me on [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)\
🐈 Follow me on [GitHub](https://github.com/heyvaldemar)

# Communication

👾 Chat with IT pros on [Discord](https://discord.gg/AJQGCCBcqf)\
📧 Reach me at ask@sre.gg

# Give Thanks

💎 Support on [GitHub](https://github.com/sponsors/heyValdemar)\
🏆 Support on [Patreon](https://www.patreon.com/heyValdemar)\
🥤 Support on [BuyMeaCoffee](https://www.buymeacoffee.com/heyValdemar)\
🍪 Support on [Ko-fi](https://ko-fi.com/heyValdemar)\
💖 Support on [PayPal](https://www.paypal.com/paypalme/heyValdemarCOM)
