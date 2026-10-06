//
//  main.swift
//  fluentkit-utils
//
//  Created by Arkivili Collindort on 01/05/2026
//

import FluentKitUtils
import Foundation

@AutoMigratable
@FluentModel("users")
final class UserSchema {
    var id: UUID?
    var name: String
    
    @Attribute(.unique)
    var email: String
    
    @Attribute(.key("avatar_url"))
    var avatarURL: String?
    
    var createdAt: Date?
    var updatedAt: Date?

    #Migration(version: 1, for: \UserSchema.name, \UserSchema.email, \UserSchema.avatarURL, \UserSchema.createdAt)
    #Migration(version: 2, for: .add(\UserSchema.updatedAt), .rename(\UserSchema.email, from: "login_email"))
}

@AutoMigratable
@FluentModel("sessions")
final class SessionSchema {
    var id: UUID?
    
    @Relationship(kind: .parent, for: UserSchema.self)
    var user: UserSchema?
    
    @Attribute(.key("ip_address"))
    var ipAddress: String
    
    @Attribute(.ignore)
    var cacheKey: String = ""
}
