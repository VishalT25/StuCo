//
//  RobustCourseAliasGenerator.swift
//  StudentCompanion
//
//  Created by Vishal Thamaraimanalan on 2025-07-02.
//

import Foundation


class RobustCourseAliasGenerator {
    
    // MARK: - Built-in Academic Knowledge Base
    private let academicDomainAliases: [String: [String]] = [
        "mathematics": ["math", "maths", "calc", "calculus", "algebra", "geometry", "trig", "statistics", "stats"],
        "computer science": ["cs", "comp sci", "compsci", "programming", "coding", "software", "it"],
        "chemistry": ["chem", "ochem", "organic", "biochem", "pchem", "analytical"],
        "biology": ["bio", "microbio", "molecular", "genetics", "anatomy", "physiology"],
        "physics": ["phys", "phy", "mechanics", "quantum", "thermo", "electromagnetism"],
        "psychology": ["psych", "psycho", "behavioral", "cognitive", "social psych"],
        "english": ["eng", "lit", "literature", "writing", "composition", "rhetoric"],
        "history": ["hist", "historical", "ancient", "modern", "medieval"],
        "economics": ["econ", "macro", "micro", "econometrics", "finance"],
        "political science": ["poli sci", "polisci", "government", "gov", "politics"],
        "philosophy": ["phil", "philo", "ethics", "logic", "metaphysics"],
        "anthropology": ["anthro", "cultural", "archaeological", "linguistic"]
    ]
    
    private let courseNumberPatterns = [
        "introduction to": ["intro", "intro to", "basics", "fundamentals", "101"],
        "advanced": ["adv", "upper", "400", "graduate", "grad"],
        "intermediate": ["inter", "mid", "200", "300"],
        "laboratory": ["lab", "practical", "hands-on"],
        "seminar": ["sem", "workshop", "discussion"],
        "independent study": ["indep", "self-directed", "research"]
    ]
    
    private let commonFillerWords = [
        "to", "of", "the", "and", "a", "an", "in", "for", "with", "on", "at", "by", "from"
    ]
    
    // MARK: - Main Generation Method
    func generateCourseAliases(from courses: [String]) -> [String: String] {
        var aliases = [String: String]()
        
        for course in courses {
            let courseAliases = generateAliasesForCourse(course)
            for alias in courseAliases {
                aliases[alias.lowercased()] = course
            }
        }
        
        return aliases
    }
    
    private func generateAliasesForCourse(_ course: String) -> [String] {
        var aliases = Set<String>()
        let normalized = course.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Strategy 1: Basic normalization
        aliases.insert(normalized)
        
        // Strategy 2: Multiple abbreviation techniques
        aliases.formUnion(generateAbbreviations(from: normalized))
        
        // Strategy 3: Academic domain knowledge
        aliases.formUnion(generateAcademicAliases(from: normalized))
        
        // Strategy 4: Course number and level handling
        aliases.formUnion(generateCourseNumberAliases(from: normalized))
        
        // Strategy 5: Phonetic and common misspelling variants
        aliases.formUnion(generatePhoneticVariants(from: normalized))
        
        // Strategy 6: Partial matching strategies
        aliases.formUnion(generatePartialMatches(from: normalized))
        
        // Strategy 7: Context-aware generation
        aliases.formUnion(generateContextAwareAliases(from: normalized))
        
        // Strategy 8: Stemming and word form variations
        aliases.formUnion(generateWordFormVariations(from: normalized))
        
        // Filter out single characters and very short aliases (except meaningful ones)
        return aliases.filter { alias in
            alias.count > 1 || ["a", "i"].contains(alias) // Keep meaningful single chars
        }.sorted()
    }
    
    // MARK: - Strategy 1: Enhanced Abbreviations
    private func generateAbbreviations(from text: String) -> Set<String> {
        var aliases = Set<String>()
        let words = text.split(separator: " ").map(String.init)
        let filteredWords = words.filter { !commonFillerWords.contains($0) }
        
        // First letter abbreviations
        let firstLetters = filteredWords.map { String($0.prefix(1)) }.joined()
        if firstLetters.count >= 2 { aliases.insert(firstLetters) }
        
        // First two letters of each word
        let firstTwoLetters = filteredWords.map { String($0.prefix(2)) }.joined()
        if firstTwoLetters.count >= 3 { aliases.insert(firstTwoLetters) }
        
        // Consonant-only abbreviations
        let consonants = filteredWords.map { word in
            String(word.filter { !"aeiou".contains($0) }.prefix(3))
        }.joined()
        if consonants.count >= 2 { aliases.insert(consonants) }
        
        // Vowel removal
        let noVowels = filteredWords.map { word in
            String(word.filter { !"aeiou".contains($0) })
        }.joined()
        if noVowels.count >= 2 { aliases.insert(noVowels) }
        
        return aliases
    }
    
    // MARK: - Strategy 2: Academic Domain Knowledge
    private func generateAcademicAliases(from text: String) -> Set<String> {
        var aliases = Set<String>()
        
        // Check against academic domain knowledge
        for (domain, domainAliases) in academicDomainAliases {
            if text.contains(domain) || domainAliases.contains(where: { text.contains($0) }) {
                aliases.formUnion(domainAliases)
            }
        }
        
        // Handle course number patterns
        for (pattern, patternAliases) in courseNumberPatterns {
            if text.contains(pattern) {
                aliases.formUnion(patternAliases)
            }
        }
        
        return aliases
    }
    
    // MARK: - Strategy 3: Course Numbers and Levels
    private func generateCourseNumberAliases(from text: String) -> Set<String> {
        var aliases = Set<String>()
        
        // Extract course numbers (e.g., "Math 101", "CS 201")
        let numberRegex = try! NSRegularExpression(pattern: "\\b([a-z]+)\\s*(\\d{3,4})\\b")
        let matches = numberRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        for match in matches {
            if let subjectRange = Range(match.range(at: 1), in: text),
               let numberRange = Range(match.range(at: 2), in: text) {
                let subject = String(text[subjectRange])
                let number = String(text[numberRange])
                
                aliases.insert("\(subject)\(number)")
                aliases.insert("\(subject) \(number)")
                aliases.insert(number)
            }
        }
        
        return aliases
    }
    
    // MARK: - Strategy 4: Phonetic Variants
    private func generatePhoneticVariants(from text: String) -> Set<String> {
        var aliases = Set<String>()
        
        // Common phonetic substitutions
        let phoneticSubstitutions: [(String, String)] = [
            ("ph", "f"), ("ck", "k"), ("qu", "kw"), ("x", "ks"),
            ("z", "s"), ("c", "k"), ("psychology", "psych"),
            ("philosophy", "phil"), ("physical", "phys")
        ]
        
        for (original, replacement) in phoneticSubstitutions {
            if text.contains(original) {
                aliases.insert(text.replacingOccurrences(of: original, with: replacement))
            }
        }
        
        return aliases
    }
    
    // MARK: - Strategy 5: Partial Matching
    private func generatePartialMatches(from text: String) -> Set<String> {
        var aliases = Set<String>()
        let words = text.split(separator: " ").map(String.init)
        let filteredWords = words.filter { !commonFillerWords.contains($0) }
        
        // Add individual meaningful words
        for word in filteredWords {
            if word.count >= 3 { // Only meaningful words
                aliases.insert(word)
            }
        }
        
        // Add last word (often the most specific)
        if let lastWord = filteredWords.last, lastWord.count >= 2 {
            aliases.insert(lastWord)
        }
        
        // Add first word (often the subject)
        if let firstWord = filteredWords.first, firstWord.count >= 2 {
            aliases.insert(firstWord)
        }
        
        // Add combinations of first and last words
        if filteredWords.count >= 2 {
            aliases.insert("\(filteredWords.first!) \(filteredWords.last!)")
            aliases.insert("\(filteredWords.first!)\(filteredWords.last!)")
        }
        
        return aliases
    }
    
    // MARK: - Strategy 6: Context-Aware Generation
    private func generateContextAwareAliases(from text: String) -> Set<String> {
        var aliases = Set<String>()
        
        // Academic context patterns
        let contextPatterns: [String: [String]] = [
            "organic": ["ochem", "orgo"],
            "calculus": ["calc", "differential", "integral"],
            "statistics": ["stats", "probability", "prob"],
            "laboratory": ["lab"],
            "seminar": ["sem"],
            "discussion": ["disc", "section"],
            "lecture": ["lec"],
            "workshop": ["shop"],
            "tutorial": ["tut"]
        ]
        
        for (keyword, contextAliases) in contextPatterns {
            if text.contains(keyword) {
                aliases.formUnion(contextAliases)
            }
        }
        
        return aliases
    }
    
    // MARK: - Strategy 7: Word Form Variations
    private func generateWordFormVariations(from text: String) -> Set<String> {
        var aliases = Set<String>()
        
        // Handle plural/singular forms
        let words = text.split(separator: " ").map(String.init)
        for word in words {
            if word.hasSuffix("s") && word.count > 3 {
                aliases.insert(String(word.dropLast())) // Remove 's'
            }
            if word.hasSuffix("ies") && word.count > 4 {
                aliases.insert(String(word.dropLast(3)) + "y") // studies -> study
            }
            if word.hasSuffix("tion") && word.count > 5 {
                aliases.insert(String(word.dropLast(4))) // introduction -> introduc
            }
        }
        
        return aliases
    }
    
    // MARK: - Enhanced Fuzzy Matching
    func findBestMatch(_ input: String, in courses: [String]) -> String? {
        let aliases = generateCourseAliases(from: courses)
        
        // Direct alias match
        if let directMatch = aliases[input.lowercased()] {
            return directMatch
        }
        
        // Fuzzy matching with multiple strategies
        var bestMatch: (course: String, score: Double) = ("", 0.0)
        
        for course in courses {
            let score = calculateComprehensiveSimilarity(input, course)
            if score > bestMatch.score {
                bestMatch = (course, score)
            }
        }
        
        return bestMatch.score > 0.6 ? bestMatch.course : nil
    }
    
    private func calculateComprehensiveSimilarity(_ input: String, _ course: String) -> Double {
        let inputLower = input.lowercased()
        let courseLower = course.lowercased()
        
        // Multiple similarity measures
        let exactMatch = inputLower == courseLower ? 1.0 : 0.0
        let containsMatch = courseLower.contains(inputLower) ? 0.8 : 0.0
        let levenshteinSimilarity = 1.0 - (Double(levenshteinDistance(inputLower, courseLower)) / Double(max(inputLower.count, courseLower.count)))
        let jaccardSimilarity = calculateJaccardSimilarity(inputLower, courseLower)
        
        // Weighted combination
        return exactMatch * 0.4 + containsMatch * 0.3 + levenshteinSimilarity * 0.2 + jaccardSimilarity * 0.1
    }
    
    private func calculateJaccardSimilarity(_ str1: String, _ str2: String) -> Double {
        let set1 = Set(str1.lowercased())
        let set2 = Set(str2.lowercased())
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)
        
        for i in 0...s1Count { matrix[i][0] = i }
        for j in 0...s2Count { matrix[0][j] = j }
        
        for i in 1...s1Count {
            for j in 1...s2Count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[s1Count][s2Count]
    }
}
