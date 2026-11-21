#!/usr/bin/env python3
"""Contrôler les commits à publier sans afficher de valeurs privées."""
import argparse
import ipaddress
import re
import subprocess
from pathlib import PurePosixPath

NOREPLY = re.compile(rb'[^@\s]+@users\.noreply\.github\.com', re.I)
IPV4 = re.compile(rb'(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])')
PRIVATE_NETS = tuple(map(ipaddress.ip_network, (
    '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '100.64.0.0/10',
)))
NETWORK_CONTEXT = re.compile(rb'(?i)\b(?:zerotier|tailscale|ssh|smb|samba|lan|dhcp|ufw|ip|ipv4|ipaddr|partage|interface)\b|\\\\')
ACCOUNT = re.compile(
    rb'(?i)\b(?:compte(?: Samba)?\s+|User(?:Name)?\s+)[\x60"\x27]'
    rb'([a-z][a-z0-9_.-]*)'
)
HOME_PATH = re.compile(rb'/home/[a-zA-Z0-9_.-]+(?=/|\b)')
EMAIL = re.compile(rb'[A-Za-z0-9._+%-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
ID = re.compile(rb'(?<![a-zA-Z0-9])[a-fA-F0-9]{16}(?![a-zA-Z0-9])')
SYNTHETIC_ACCOUNTS = {b'example', b'exemple', b'test', b'utilisateur', b'user'}


def git(*args, **kwargs):
    return subprocess.check_output(('git', *args), **kwargs)


def private_path(path):
    parts = PurePosixPath(path).parts
    name = parts[-1]
    return (any(p in {'.ssh', '.aws', '.shots'} for p in parts)
            or name == '.env' or name.startswith('.env.')
            or name.endswith(('.pem', '.key', '.ovpn', '.kdbx', '.log'))
            or name in {'zerotier-network', 'zerotier-network.local', 'authtoken.secret', 'identity.secret'}
            or path.startswith('dotfiles/samba/hosts/') and name.endswith('.conf'))


def added_line_issue(path, line, previous=b''):
    if not path.endswith('.md'):
        return None
    context = previous + b' ' + line
    if HOME_PATH.search(line):
        return 'chemin de compte local'
    if re.search(rb'(?i)\b(?:ZeroTier|Network ID)\b', context) and ID.search(line):
        return 'identifiant de réseau'
    if NETWORK_CONTEXT.search(context):
        for raw in IPV4.findall(line):
            try:
                address = ipaddress.ip_address(raw.decode('ascii'))
            except ValueError:
                continue
            if any(address in net for net in PRIVATE_NETS):
                return 'adresse réseau privée'
        account = ACCOUNT.search(line)
        if account and account[1].lower() not in SYNTHETIC_ACCOUNTS:
            return 'nom de compte réseau'
    if path == 'PROGRESS.md' or path.startswith('docs/archive/'):
        for address in EMAIL.findall(line):
            if not NOREPLY.fullmatch(address) and not address.lower().endswith(b'@example.invalid'):
                return 'adresse de contact dans un journal'
    return None


def check_commit(commit):
    for label, value in zip(('auteur', 'committer'),
                            git('show', '-s', '--format=%ae%n%ce', commit).splitlines()):
        if not NOREPLY.fullmatch(value):
            yield f'{label} sans adresse GitHub noreply'
    # -m inspecte également les changements propres à un commit de fusion.
    diff_flags = ('--root', '-m', '--no-commit-id', '--no-renames', '--no-ext-diff', '--no-textconv')
    paths = git('diff-tree', *diff_flags, '-r', '-z', '--name-only', '--diff-filter=AMT', commit)
    for raw in dict.fromkeys(paths.split(b'\0')):
        if not raw:
            continue
        path = raw.decode('utf-8', 'surrogateescape')
        if private_path(path):
            yield f'{ascii(path)} — fichier privé'
            continue
        if not path.endswith('.md'):
            continue
        diff = git('diff-tree', *diff_flags, '-U1', commit, '--', path)
        previous = b''
        for line in diff.splitlines():
            if line.startswith((b' ', b'+')) and not line.startswith(b'+++'):
                text = line[1:]
                if line.startswith(b'+'):
                    issue = added_line_issue(path, text, previous)
                    if issue:
                        yield f'{ascii(path)} — {issue}'
                previous = text
            elif not line.startswith(b'-'):
                previous = b''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('head', help='nouvelle référence')
    parser.add_argument('base', nargs='?', help='ancienne référence, si connue')
    args = parser.parse_args()
    revisions = [args.head]
    if args.base and args.base.strip('0') and subprocess.run(
            ('git', 'cat-file', '-e', f'{args.base}^{{commit}}'), stderr=subprocess.DEVNULL).returncode == 0:
        revisions.append(f'^{args.base}')
    failed = False
    for raw in git('rev-list', *revisions, '--').splitlines():
        commit = raw.decode('ascii')
        for issue in dict.fromkeys(check_commit(commit)):
            print(f'{commit[:12]} {issue}')
            failed = True
    return int(failed)


if __name__ == '__main__':
    raise SystemExit(main())
