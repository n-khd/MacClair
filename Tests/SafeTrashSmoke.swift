import Foundation
import CryptoKit

@main
struct SafeTrashSmoke {
    static func main() throws {
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("macclair-trash-\(UUID())")
        defer { try? fm.removeItem(at: home) }
        let downloads = home.appendingPathComponent("Downloads")
        try fm.createDirectory(at: downloads, withIntermediateDirectories: true)
        let first = downloads.appendingPathComponent("document réel.pdf")
        let second = downloads.appendingPathComponent("copie.pdf")
        try Data("test".utf8).write(to: first)
        try Data("test".utf8).write(to: second)
        let safe = SafeTrash(home: home)
        let candidate = try safe.capture(first)
        try safe.validate(candidate)
        try safe.validateDuplicateSelection([first], groups: [[first, second]])
        do {
            try safe.validateDuplicateSelection([first, second], groups: [[first, second]])
            preconditionFailure("Dernière copie autorisée")
        } catch TrashError.lastDuplicate {}
        try Data("modifié".utf8).write(to: first)
        do {
            try safe.validate(candidate)
            preconditionFailure("Modification non détectée")
        } catch TrashError.changed {}
        // A stale scan must never authorize moving a file as a duplicate.
        let digest = SHA256.hash(data: Data("test".utf8)).map { String(format: "%02x", $0) }.joined()
        let secondCandidate = try safe.capture(second)
        try Data("test".utf8).write(to: first)
        try safe.validateDuplicate(secondCandidate, keeper: first, expectedDigest: digest)
        try Data("autre".utf8).write(to: first)
        do {
            try safe.validateDuplicate(secondCandidate, keeper: first, expectedDigest: digest)
            preconditionFailure("Copie conservée modifiée autorisée")
        } catch TrashError.duplicateChanged {}
        try fm.removeItem(at: first)
        do {
            try safe.validateDuplicate(secondCandidate, keeper: first, expectedDigest: digest)
            preconditionFailure("Copie conservée absente autorisée")
        } catch TrashError.duplicateChanged {}
        try Data("test".utf8).write(to: first)
        try Data("change".utf8).write(to: second)
        do {
            try safe.validateDuplicate(secondCandidate, keeper: first, expectedDigest: digest)
            preconditionFailure("Doublon modifié autorisé")
        } catch TrashError.changed {}
        try Data("else".utf8).write(to: second)
        let staleCandidate = try safe.capture(second)
        do {
            try safe.validateDuplicate(staleCandidate, keeper: first, expectedDigest: digest)
            preconditionFailure("Contenu changé depuis l’analyse autorisé")
        } catch TrashError.duplicateChanged {}
        try Data("test".utf8).write(to: second)
        let outside = home.appendingPathComponent("Library/test.pdf")
        try fm.createDirectory(at: outside.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("autre".utf8).write(to: outside)
        do {
            _ = try safe.capture(outside)
            preconditionFailure("Dossier hors Téléchargements autorisé")
        } catch TrashError.outsideDownloads {}
        let link = downloads.appendingPathComponent("lien.pdf")
        try fm.createSymbolicLink(at: link, withDestinationURL: second)
        do {
            _ = try safe.capture(link)
            preconditionFailure("Lien symbolique autorisé")
        } catch TrashError.notRegularFile {}
        let gitPack = downloads.appendingPathComponent("projet/.git/objects/pack/data.pack")
        try fm.createDirectory(at: gitPack.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("pack".utf8).write(to: gitPack)
        do {
            _ = try safe.capture(gitPack)
            preconditionFailure("Fichier Git interne autorisé")
        } catch TrashError.protectedPath {}
        let oldest = downloads.appendingPathComponent("original.txt")
        let extraA = downloads.appendingPathComponent("copie-a.txt")
        let extraB = downloads.appendingPathComponent("copie-b.txt")
        let safeWithProtected = downloads.appendingPathComponent("copie-projet.pack")
        for url in [oldest, extraA, extraB, safeWithProtected] {
            try Data("contenu identique".utf8).write(to: url)
        }
        try fm.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_000_000)],
                             ofItemAtPath: oldest.path)
        let groups = [[extraB, oldest, extraA], [gitPack, safeWithProtected]]
        let cautious = safe.planRedundantDuplicates(groups: groups)
        precondition(cautious.selected.count == 2 && cautious.groupsSkipped == 1)
        let plan = safe.planRedundantDuplicates(groups: groups,
                                                 includeProjectAndOtherFolders: true)
        precondition(plan.selected.count == 3)
        precondition(plan.selected[oldest] == nil)
        precondition(plan.selected[extraA] != nil && plan.selected[extraB] != nil)
        precondition(plan.selected[safeWithProtected] != nil)
        precondition(plan.keepers.contains(oldest) && plan.keepers.contains(gitPack))
        precondition(plan.groupsPrepared == 2 && plan.protectedFiles == 1)
        precondition(plan.groupsSkipped == 0)
        try safe.validateDuplicateSelection(Set(plan.selected.keys),
                                            groups: groups)
        let project = downloads.appendingPathComponent("application")
        try fm.createDirectory(at: project, withIntermediateDirectories: true)
        try Data().write(to: project.appendingPathComponent("Package.swift"))
        let projectA = project.appendingPathComponent("a.txt")
        let projectB = project.appendingPathComponent("b.txt")
        try Data("same".utf8).write(to: projectA)
        try Data("same".utf8).write(to: projectB)
        precondition(safe.planRedundantDuplicates(groups: [[projectA, projectB]]).selected.isEmpty)
        print("SafeTrashSmoke OK: dossier, identité, lien et copie conservée")
    }
}
