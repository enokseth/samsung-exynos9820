#!/bin/bash
#usr/magisk/update_magisk.sh

# Arrête le script si une commande retourne une erreur
set -e

# Détermine le répertoire où se trouve le script
# `dirname` donne le chemin du répertoire contenant le script
# `pwd` retourne le chemin absolu
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Lit la version actuelle de Magisk à partir du fichier `magisk_version` ou définit 'none' si le fichier n'existe pas
ver="$(cat "$DIR/magisk_version" 2>/dev/null || echo -n 'none')"

# Vérifie l'argument fourni ($1) pour déterminer la version à utiliser
if [ "x$1" = "xcanary" ]; then
    # Utilise la version "canary" de Magisk
    nver="canary"
    magisk_link="https://github.com/topjohnwu/magisk-files/raw/${nver}/app-debug.apk"
elif [ "x$1" = "xalpha" ]; then
    # Utilise la version "alpha" de Magisk
    nver="alpha"
    magisk_link="https://github.com/vvb2060/magisk_files/raw/${nver}/app-release.apk"
else
    # Utilise une version stable si aucun argument n'est fourni ou si une version spécifique est demandée
    dash='-'
    if [ "x$1" = "x" ]; then
        # Récupère la dernière version stable à partir des releases GitHub
        nver="$(curl -s https://github.com/topjohnwu/Magisk/releases | grep -m 1 -Poe 'Magisk v[\d\.]+' | cut -d ' ' -f 2)"
    else
        # Utilise la version spécifiée
        nver="$1"
    fi

    # Si la version est `v26.3`, change le séparateur dans l'URL
    if [ "$nver" = "v26.3" ]; then
        dash='.'
    fi
    magisk_link="https://github.com/topjohnwu/Magisk/releases/download/${nver}/Magisk${dash}${nver}.apk"
fi

# Vérifie si une mise à jour est nécessaire
if [ \( -n "$nver" \) -a \( "$nver" != "$ver" \) -o ! \( -f "$DIR/magiskinit" \) -o \( "$nver" = "canary" \) -o \( "$nver" = "alpha" \) ]; then
    # Si une mise à jour est nécessaire, télécharge la nouvelle version
    echo "Updating Magisk from $ver to $nver"
    curl -s --output "$DIR/magisk.zip" -L "$magisk_link"

    # Vérifie si le fichier téléchargé est valide
    if fgrep 'Not Found' "$DIR/magisk.zip"; then
        # Si le fichier est invalide, essaye une autre extension (zip au lieu de apk)
        curl -s --output "$DIR/magisk.zip" -L "${magisk_link%.apk}.zip"
    fi

    # Extrait les fichiers nécessaires du fichier zip
    if unzip -o "$DIR/magisk.zip" arm/magiskinit64 -d "$DIR"; then
        # Si `magiskinit64` est trouvé, l'extrait
        mv -f "$DIR/arm/magiskinit64" "$DIR/magiskinit"
        : > "$DIR/magisk32.xz"  # Crée un fichier vide pour magisk32.xz
        : > "$DIR/magisk64.xz"  # Crée un fichier vide pour magisk64.xz
    elif unzip -o "$DIR/magisk.zip" lib/armeabi-v7a/libmagiskinit.so lib/armeabi-v7a/libmagisk32.so lib/armeabi-v7a/libmagisk64.so -d "$DIR"; then
        # Si les fichiers sont dans un autre format, les extrait et les compresse avec xz
        mv -f "$DIR/lib/armeabi-v7a/libmagiskinit.so" "$DIR/magiskinit"
        mv -f "$DIR/lib/armeabi-v7a/libmagisk32.so" "$DIR/magisk32"
        mv -f "$DIR/lib/armeabi-v7a/libmagisk64.so" "$DIR/magisk64"
        xz --force --check=crc32 "$DIR/magisk32" "$DIR/magisk64"
    elif unzip -o "$DIR/magisk.zip" lib/arm64-v8a/libmagiskinit.so lib/armeabi-v7a/libmagisk32.so lib/arm64-v8a/libmagisk64.so assets/stub.apk -d "$DIR"; then
        # Si le fichier contient également un stub.apk, extrait tous les fichiers nécessaires
        mv -f "$DIR/lib/arm64-v8a/libmagiskinit.so" "$DIR/magiskinit"
        mv -f "$DIR/lib/armeabi-v7a/libmagisk32.so" "$DIR/magisk32"
        mv -f "$DIR/lib/arm64-v8a/libmagisk64.so" "$DIR/magisk64"
        mv -f "$DIR/assets/stub.apk" "$DIR/stub"
        xz --force --check=crc32 "$DIR/magisk32" "$DIR/magisk64" "$DIR/stub"
    else
        # Dernière tentative d'extraction
        unzip -o "$DIR/magisk.zip" lib/arm64-v8a/libmagiskinit.so lib/armeabi-v7a/libmagisk32.so lib/arm64-v8a/libmagisk64.so -d "$DIR"
        mv -f "$DIR/lib/arm64-v8a/libmagiskinit.so" "$DIR/magiskinit"
        mv -f "$DIR/lib/armeabi-v7a/libmagisk32.so" "$DIR/magisk32"
        mv -f "$DIR/lib/arm64-v8a/libmagisk64.so" "$DIR/magisk64"
        xz --force --check=crc32 "$DIR/magisk32" "$DIR/magisk64"
    fi

    # Met à jour le fichier `magisk_version` avec la nouvelle version
    echo -n "$nver" > "$DIR/magisk_version"

    # Supprime le fichier zip téléchargé pour économiser de l'espace
    rm "$DIR/magisk.zip"

    # Crée ou met à jour un fichier vide `initramfs_list`
    touch "$DIR/initramfs_list"
else
    # Si aucune mise à jour n'est nécessaire, affiche un message
    echo "Nothing to be done: Magisk version $nver"
fi

