graph LR
    Root[Edufwesh Enterprise Architecture] --> API[1. Cloud API & Brain]
    Root --> Install[2. Installers & OTA Updates]
    Root --> Protocols[3. Protocol Services]
    Root --> IAM[4. Identity Access]
    Root --> Security[5. Security & Autokill]
    Root --> Daemons[6. Background Daemons]
    Root --> CLI[7. Interfaces & Backup]

    API --> bot[bot.py]

    Install --> core[core-engine]
    Install --> warp_inst[edufwesh-warp-install]
    Install --> update[edufwesh-update]
    Install --> push[edufwesh-push-update]

    Protocols --> svcs[edufwesh-services]
    Protocols --> ws_ssh[edufwesh-wsepro-ssh]
    Protocols --> ws_drop[edufwesh-wsepro-dropbear]

    IAM --> create[edufwesh-creator]
    IAM --> admin[edufwesh-admin]

    Security --> kill[edufwesh-autokill]
    Security --> enforce[edufwesh-enforcer]

    Daemons --> quota[edufwesh-quota-engine]
    Daemons --> flash[edufwesh-flash-reaper]
    Daemons --> cleaner[edufwesh-cleaner]
    Daemons --> ssl[edufwesh-ssl-renew]

    CLI --> gui[edufwesh-webgui]
    CLI --> backup[edufwesh-do-backup]
    CLI --> warp_tog[edufwesh-warp-toggle]
    CLI --> m_main[menu]
    CLI --> m_ssh[menu-ssh]
    CLI --> m_xray[menu-xray]
    CLI --> m_sec[menu-security]
    CLI --> m_dom[menu-domain]
    CLI --> m_set[menu-settings]
    CLI --> m_bak[menu-backup]
