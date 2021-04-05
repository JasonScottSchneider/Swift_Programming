import Foundation

enum Player: String {
    case dealer, player
}

// todo add split, double, etc
enum Move: String {
    
    case hit   = "hit"
    case stand = "stand"
    case hint  = "hint"
    
    init?() {
        if let move = Move(rawValue: Input.getCurrentLine()) {
            self = move
        } else {
            return nil
        }
    }
}

struct Hint {
    
    let dealerHand: Hand
    let playerHand: Hand
    
    init(dealerHand: Hand, playerHand: Hand) {
        self.dealerHand = dealerHand
        self.playerHand = playerHand
    }
    
    /// Uses a prob dist table that maximizes expectation
    func bestMove() -> Move {
        
        let playerSum = playerHand.sum
        let dealerSum = dealerHand.sum
        
        if playerHand.cards.contains(where: { $0.isAce }) {
            // soft hand

            let aceCount = playerHand.cards.filter { $0.isAce }.count
            // let each ace count as 1, not 11
            let softSum = Hand(type: .player, cards: playerHand.cards.filter { $0.isAce == false }).sum + aceCount
            if softSum >= 8 {
                return .stand
            }
            if softSum == 7 {
                if dealerSum <= 3 || dealerSum >= 7 {
                    return .hit
                }
                return .stand
            }
            
            return .hit
        }
        
        // no aces
        
        if playerSum >= 17 {
            return .stand
        }
        
        if playerSum >= 13 {
            if dealerSum >= 7 {
                return .hit
            } else {
                return .stand
            }
        }
        
        if playerSum == 12 {
            if dealerSum <= 3 || dealerSum >= 7 {
                return .hit
            } else {
                return .stand
            }
        }
        
        // player hand <= 11
        return .hit
        
    }
}

enum Card {
    case ace(name: String, soft: Int, hard: Int) // either 1 or 11
    case notAce(name: String, value: Int)
}

extension Card {
    static let possibleValues: [Card] = [
        .ace(name: "Ace", soft: 1, hard: 11),
        .notAce(name: "1"    , value: 1),
        .notAce(name: "2"    , value: 2),
        .notAce(name: "3"    , value: 3),
        .notAce(name: "4"    , value: 4),
        .notAce(name: "5"    , value: 5),
        .notAce(name: "6"    , value: 6),
        .notAce(name: "7"    , value: 7),
        .notAce(name: "8"    , value: 8),
        .notAce(name: "9"    , value: 9),
        .notAce(name: "10"   , value: 10),
        .notAce(name: "Jack" , value: 10),
        .notAce(name: "Queen", value: 10),
        .notAce(name: "King" , value: 10)
    ]
    
    var softValue: Int {
        switch self {
            case .ace(name: _, soft: let soft, hard: _): return soft
            case .notAce(name: _, value: let val): return val
        }
    }
    
    var hardValue: Int {
        switch self {
            case .ace(name: _, soft: _, hard: let hard): return hard
            case .notAce(name: _, value: let val): return val
        }
    }
    
    var name: String {
        switch self {
            case .ace(name: let name, soft: _, hard: _): return name
            case .notAce(name: let name, value: _): return name
        }
    }
    
    var isAce: Bool {
        name == "Ace"
    }
    
    init() {
        // Chooses a card from an uniform distribution
        // See https://github.com/apple/swift-evolution/blob/master/proposals/0202-random-unification.md
        self = Self.possibleValues.randomElement()!
    }
    
}

struct Hand {
    
    var type: Player
    var cards: [Card] // initially 2, but hitting can increase
    var standing = false
    
    var sum: Int {
        // TODO: - WHAT IF THEY HAVE MULTIPLE ACES?
        // the softSum would reduce every ace to equal 1;
        // however, what if there were 2 ace's, for a total of 1 + 11 = 12?
        // Well, it doesn't matter since 12 has a lower expectation than 2 soft aces.
        // See the Hint class for more info.
        let softValue = cards.reduce(0, { $0 + $1.softValue })
        let hardValue = cards.reduce(0, { $0 + $1.hardValue })
        if hardValue <= 21 {
            return hardValue
        }
        return softValue
    }
    
    var isBlackjack: Bool {
        sum == 21
    }
    
    init(type: Player) {
        self.type = type
        
        // each player starts with 2 cards
        self.cards = [Card(), Card()]
    }
    
    init(type: Player, cards: [Card]) {
        self.type = type
        self.cards = cards
    }
    
    mutating func hit() {
        self.cards.append(Card())
    }
    
    mutating func stand() {
        self.standing = true
    }
    
    func getHint(dealerHand: Hand) {
        let bestMove = Hint(dealerHand: dealerHand, playerHand: self).bestMove()
        print("The ideal move is to \(bestMove)")
    }
}

enum Input: String {
    case quit = "q" // exit process
    case help = "h" // print rules
    case play = "p"
    case error
    
    init() {
        self = Input(rawValue: Self.getCurrentLine()) ?? .error
    }
    
    static func getCurrentLine() -> String {
        /// read data from stdin,
        /// initialize the data to a string,
        /// and drop the newline chars
        let data = FileHandle.standardInput.availableData
        let strData = String(data: data, encoding: .utf8)!
        return strData.trimmingCharacters(in: .newlines)
    }
}

struct Game {
    
    let maxCoins: Double = 1000
    
    func play() {
        
        welcome()
        
        guard wantsToPlay() else {
            return
        }
        
        var coins = maxCoins
        
        // Game Loop - runs until losing or quitting
        while true {
            
            if coins <= 0 {
                print("You have no more coins! Game Over")
                return
            }
            
            let betSize = getBetSize(currentCoins: coins)
            var dealersHand = Hand(type: .dealer)
            if dealersHand.isBlackjack {
                // dealer auto wins
                print("Dealer automatically won by blackjack 21!")
                gameOutcome(winner: .dealer, playerCoins: &coins, betSize: betSize, wasPlayerBlackjack: false)
                continue
            }
            
            print("Dealer's Hand: \(dealersHand.cards[0].name), ?")
            
            let playersHand = finalizePlayerHand(dealerHand: dealersHand)
            
            if playersHand.sum > 21 {
                // bust
                print("You busted! Player hand = \(playersHand.sum)")
                gameOutcome(winner: .dealer, playerCoins: &coins, betSize: betSize, wasPlayerBlackjack: false)
                continue
            }
            
            // hard 17
            while dealersHand.sum <= 17 {
                // keep hitting
                dealersHand.hit()
                print("Dealer hit, now at \(dealersHand.sum)")
            }
            
            if dealersHand.sum > 21 || playersHand.sum > dealersHand.sum {
                // player won
                gameOutcome(winner: .player, playerCoins: &coins, betSize: betSize, wasPlayerBlackjack: playersHand.sum == 21)
            } else if playersHand.sum == dealersHand.sum {
                // get your money back
                print("Tie, no change in coins")
            } else {
                // dealer won
                gameOutcome(winner: .dealer, playerCoins: &coins, betSize: betSize, wasPlayerBlackjack: false)
            }
            
        }
    }
    
    private func welcome() {
        print("Welcome to Blackjack")
        print("Press \"p\" to play, \"h\" for help, and \"q\" to quit")
    }
    
    private func wantsToPlay() -> Bool {
        var input = Input()
        while input == .error {
            print("Invalid option, try again")
            input = Input()
        }
        
        switch input {
            case .quit: break
            case .help: help(); break
            case .error: print("Invalid option, try again")
            case .play: return true
        }
        
        return false
    }
    
    private func getBetSize(currentCoins: Double) -> Double {
        print("You have \(currentCoins) coins. How much would you like to bet, from 0 - \(min(maxCoins, currentCoins))?")
        
        var input = Input.getCurrentLine()
        while Double(input) == nil || Double(input)! > currentCoins {
            print("Invalid bet size, try again.")
            input = Input.getCurrentLine()
        }
        
        return Double(input)!
    }
    
    private func finalizePlayerHand(dealerHand: Hand) -> Hand {
        var playersHand = Hand(type: .player)
        
        while playersHand.sum <= 21 && playersHand.standing == false {
            print("Your Hand: \(playersHand.cards.reduce("", {$0 + $1.name + ", "}).dropLast(2))")
            print("Would you like to \"hit\", \"stand\", or receive a \"hint\"?")
            switch Move() {
                case .hit:
                    playersHand.hit()
                case .stand:
                    playersHand.stand()
                case .hint:
                    playersHand.getHint(dealerHand: dealerHand)
                case .none:
                    print("Invalid choice.")
                    continue
            }
            
        }
        
        return playersHand
    }
    
    private func gameOutcome(winner: Player, playerCoins: inout Double, betSize: Double, wasPlayerBlackjack: Bool) {
        let blackjackBonusMultiple = 1.5
        print("Winner was the \(winner.rawValue)!")
        switch winner {
            case .player:
                playerCoins += wasPlayerBlackjack ? betSize * blackjackBonusMultiple : betSize
            case .dealer:
                playerCoins -= betSize
        }
        print("Player coins is now \(playerCoins)")
    }
    
    private func help() {
        print("""
                This game makes several simplifications for now.
                It assumes a continuous shuffle machine rather than a fixed set of decks.
                Dealer hits on a hard 17.
                No splitting, no doubling, no surrendering, etc.
                Only original bets are lost on dealer blackjack, although the dealer wins immediately.
              """)
    }
}

Game().play()

