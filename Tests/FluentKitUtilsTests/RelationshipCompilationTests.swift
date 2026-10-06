import FluentKitUtils
import Foundation

@FluentModel
private final class ConventionParent {
    var id: UUID?

    @Relationship(kind: .child, for: ConventionChild.self)
    var children: [ConventionChild]

    @Relationship(kind: .child, for: ConventionProfile.self)
    var profile: ConventionProfile?
}

@FluentModel
private final class ConventionChild {
    var id: UUID?

    @Relationship(kind: .parent)
    var conventionParent: ConventionParent
}

@FluentModel
private final class ConventionProfile {
    var id: UUID?

    @Relationship(kind: .parent)
    var conventionParent: ConventionParent
}
