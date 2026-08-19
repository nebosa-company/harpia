# Compatibility shim. The backup helpers now live in the BackupKit
# module; dot-sourcing this file keeps the old call sites working.

$backupKitManifest = Join-Path $PSScriptRoot '..\modules\BackupKit\BackupKit.psd1'
Import-Module -Name $backupKitManifest -Force -Global -ErrorAction Stop
