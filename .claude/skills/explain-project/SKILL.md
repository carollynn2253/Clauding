---
name: explain-project
description: Read and explain a project's structure, architecture, tech stack, and key components
argument-hint: [/path/to/project]
---

Explore and explain the project at **$ARGUMENTS**.

## Steps

1. **Discover project type and structure:**
   - Read root config files (package.json, build.gradle, pom.xml, Cargo.toml, go.mod, pyproject.toml, Podfile, etc.)
   - Read README.md, CLAUDE.md, or any top-level documentation
   - List the top-level directory structure

2. **Identify tech stack:**
   - Language(s) and version(s)
   - Framework(s) (e.g., Spring, React, Jetpack Compose, Flask, etc.)
   - Build tool (Gradle, Maven, npm, Cargo, etc.)
   - DI framework (Hilt, Koin, Dagger, etc.) if applicable
   - Database / ORM if applicable
   - Testing frameworks

3. **Map the architecture:**
   - Identify the architectural pattern (MVC, MVVM, Clean Architecture, layered, modular, monorepo, etc.)
   - List key modules / packages and their responsibilities
   - Identify entry points (main activity, main function, route definitions, etc.)
   - Note navigation approach if it's a UI app

4. **Highlight key components:**
   - Core business logic locations
   - API / networking layer
   - Data layer (repositories, DAOs, models)
   - UI layer structure
   - Shared utilities or base classes
   - Configuration and environment setup

5. **Summarize:**
   - Provide a concise overview (what the project does, how it's organized)
   - List the tech stack in a table
   - Show the high-level directory tree with brief descriptions
   - Note any patterns, conventions, or notable design decisions
