<img width="600" height="600" alt="MLogoTrans" src="https://github.com/user-attachments/assets/cdd6f5f3-d60d-4c8d-b315-f0f6c4bd4c6f" />
# Madonis
 Admin System

**Madonis** is a powerful, modular, and community-driven server moderation and management system for Roblox. Designed for flexibility, security, and extensibility, Madonis empowers game creators to manage their experiences with advanced admin tools, plugin support, and robust APIs.

---

## 🚀 Features

- **Modern Admin Commands:** Ban, kick, mute, rank, logs, and more.
- **Role & Permission System:** Fine-grained control over admin levels and access.
- **Plugin Architecture:** Easily extend Madonis with custom plugins (server & client).
- **WebSocket Integration:** Real-time external API calls and cross-server communication.
- **Anti-Exploit & Security:** Built-in anti-cheat, anti-spam, and player validation.
- **Customizable UI:** Multiple themes and UI layouts for both desktop and mobile.
- **Rate Limiting:** Prevents abuse of commands and remote events.
- **Debug & Developer Tools:** Toggle debug mode, inspect logs, and use developer APIs.
- **DataStore Integration:** Secure, customizable data storage for bans, ranks, and more.
- **Extensive Logging:** Track commands, joins, leaves, errors, and more.
- **Cross-Server Messaging:** Send messages and actions between game servers.
- **Localization Ready:** Easily adapt for different languages and regions.

---

## 📦 Installation

### 1. Roblox Model (Recommended)
- [Get the official Madonis Loader](https://www.roblox.com/library/7510622625/)
- Insert into `ServerScriptService` in Roblox Studio.

### 2. GitHub Releases
- [Download the latest release](https://github.com/Epix-Incorporated/Adonis/releases/latest)
- Import the `.rbxm` file into Studio.

### 3. Source/Filesystem (Advanced)
- Clone this repository.
- Use [Rojo](https://rojo.space/) or similar tools to build and sync to Studio.
- Example: `rojo build . -o Madonis.rbxmx`

> **Note:** Filesystem builds may include experimental or unstable features.

---

## ⚙️ Configuration

1. **Settings:**  
   Edit `Adonis_Loader/Config/Settings.luau` to customize permissions, DataStore keys, UI, and more.
2. **Debug Mode:**  
   Enable `DebugMode` in the loader to use local modules and developer features.
3. **Plugins:**  
   Add your own plugins to `MainModule/Server/Plugins` or `MainModule/Client/Plugins`.
4. **Themes:**  
   Switch UI themes in `MainModule/Client/UI`.

---

## 🛡️ Security & Anti-Exploit

- **Anti-Cheat:** Detects and blocks common exploit attempts.
- **Rate Limiting:** Prevents command and remote event spam.
- **Whitelist & Ban System:** Robust player filtering and ban management.
- **Server Lock:** Restrict access during maintenance or emergencies.

---

## 🔌 Extending Madonis

- **Plugins:**  
  Write custom plugins for new commands, integrations, or UI features.
- **WebSocket API:**  
  Integrate with external services using the built-in RoSocket module.
- **Themes:**  
  Create and apply custom UI themes for your community.

---

## 📝 Documentation & Support

- [Official Wiki & Docs](https://github.com/Epix-Incorporated/Adonis/wiki)
- [User Manual & Feature Showcase](https://github.com/Epix-Incorporated/Adonis/wiki/User-Manual-&-Feature-Showcase)
- [Discord Community](https://discord.gg/H5RvTP3)
- [Roblox Group](https://www.roblox.com/groups/886423)

---

## 🤝 Contributing

We welcome contributions!  
See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

- Fork the repo and submit a pull request.
- Report issues or suggest features via GitHub Issues.
- Join the Discord for real-time help and discussion.

---

## ⚖️ License

Madonis is released under the [MIT License](LICENSE.md).

---

## 💡 Credits

Thanks to all contributors and the Roblox developer community for making Madonis possible!

[![contributors](https://contributors-img.web.app/image?repo=Epix-Incorporated/Adonis)](https://github.com/Epix-Incorporated/Adonis/graphs/contributors)

