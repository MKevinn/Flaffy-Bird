//
//  GameScene.swift
//  Flaffy Bird
//
//  Created by Jintian Wang on 2020/7/10.
//  Copyright © 2020 Jintian Wang. All rights reserved.
//

import SpriteKit
import GameplayKit
import AudioToolbox
import FirebaseAnalytics

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    static var movedToGame = false
    
    private var jumpAd = false
    
    let birdTimePerFrame = 0.1
    let maxTimeBgMoving: CGFloat = 3
    let bgAnimatedInSecs: TimeInterval = 7

    var bird: SKSpriteNode = SKSpriteNode()
    var background: SKSpriteNode = SKSpriteNode()
    var score: Int = 0
    var gameOver: Bool = false
    var gameOverLabel: SKLabelNode = SKLabelNode()
    var timer: Timer = Timer()
    
    private var timesPlayed = 0

    enum ColliderType: UInt32 {
        case Bird = 1
        case Object = 2
        case Gap = 4
    }

    override func didMove(to view: SKView) {
        NotificationCenter.default.addObserver(self, selector: #selector(continueGame), name: .continueGame, object: nil)
        self.physicsWorld.contactDelegate = self
        initializeGame()
    }

    func initializeGame() {
        
        timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(self.drawPipes), userInfo: nil, repeats: true)
        
        drawBackground()
        drawBird()
        drawPipes()
        
        if !jumpAd {
            timesPlayed += 1
            Analytics.logEvent("bird_played", parameters: [
                "times_played": timesPlayed,
                "l": UserDefaults.standard.string(forKey: K.r) ?? "Unknown..."
            ])
        }
    }

    func drawBird() {
        let birdTexture = SKTexture(imageNamed: "canary1")
        let birdTexture2 = SKTexture(imageNamed: "canary2")

        let animation = SKAction.animate(with: [birdTexture, birdTexture2], timePerFrame: birdTimePerFrame)
        let makeBirdFlap = SKAction.repeatForever(animation)

        bird = SKSpriteNode(texture: birdTexture)

        bird.position = CGPoint(x: self.frame.midX, y: self.frame.midY)
        bird.run(makeBirdFlap)

        // For colisions
        bird.physicsBody = SKPhysicsBody(circleOfRadius: birdTexture.size().height / 2)

        bird.physicsBody!.isDynamic = false

        bird.physicsBody!.contactTestBitMask = ColliderType.Object.rawValue
        bird.physicsBody!.categoryBitMask = ColliderType.Bird.rawValue
        bird.physicsBody!.collisionBitMask = ColliderType.Bird.rawValue

        self.addChild(bird)

        makeGround()
    }

    func drawBackground() {
        let bgTexture = SKTexture(imageNamed: BirdViewController.bk)

        let moveBgAnimation = SKAction.move(by: CGVector(dx: -bgTexture.size().width, dy: 0), duration: bgAnimatedInSecs)
        let shiftBgAnimation = SKAction.move(by: CGVector(dx: bgTexture.size().width, dy: 0), duration: 0)
        let bgAnimation = SKAction.sequence([moveBgAnimation, shiftBgAnimation])
        let moveBgForever = SKAction.repeatForever(bgAnimation)

        var i: CGFloat = 0

        while i < maxTimeBgMoving {
            background = SKSpriteNode(texture: bgTexture)
            background.position = CGPoint(x: bgTexture.size().width * i, y: self.frame.midY)
            background.size.height = self.frame.height
            background.run(moveBgForever)

            self.addChild(background)

            i += 1

            // Set background first
            background.zPosition = -2
        }
    }
    
    // Draws the pipes and move them around the bird
    @objc func drawPipes() {
        
        let gapHeight = bird.size.height * 4

        let movePipes = SKAction.move(
            by: CGVector(dx: -2 * self.frame.width, dy: 0),
            duration: TimeInterval(self.frame.width / 100)
        )

        let removePipes = SKAction.removeFromParent()

        let movementAmount = arc4random() % UInt32(self.frame.height / 2)
        let moveAndRemovePipes = SKAction.sequence([movePipes, removePipes])

        let pipeOffset = CGFloat(movementAmount) - self.frame.height / 4

        if !GameScene.movedToGame {return}
        
        makePipe1(moveAndRemovePipes, gapHeight, pipeOffset)
        makePipe2(moveAndRemovePipes, gapHeight, pipeOffset)
        makeGap(moveAndRemovePipes, gapHeight, pipeOffset)
    }

    func didBegin(_ contact: SKPhysicsContact) {
        if gameOver == false {
            if contact.bodyA.categoryBitMask == ColliderType.Gap.rawValue ||
                contact.bodyB.categoryBitMask == ColliderType.Gap.rawValue {
                score += 1
                
                NotificationCenter.default.post(Notification(name: .didUpdatePoint, object: score, userInfo: nil))

            } else {
                
                if !GameScene.movedToGame {resetGame(); return}
                
                AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(4095), nil)
                
                BirdViewController.isEarned = false
                
                BirdViewController.prevScore = score
                
                resetGame()

                setMessageScoreStyle()
                gameOverLabel.text = BirdViewController.hasSucceeded ? "Succeed! 😁".localized : "Try Again :)".localized
                gameOverLabel.position = CGPoint(x: self.frame.midY, y: self.frame.midY)
                
                if score>UserDefaults.standard.integer(forKey: K.birdBestScore) {
                    gameOverLabel.text = "\("A New Record".localized) \(["🥰","😜","🥳","✊"].randomElement() ?? "🥳")     "
                    NotificationCenter.default.post(Notification(name: .didOccurNewRecord, object: score, userInfo: nil))
                }
                
//                if UserDefaults.standard.bool(forKey: K.isPremium) {
                if true {
                                            // last && and code after subject to deletion
                    if !BirdViewController.hasSucceeded && !jumpAd && (UserDefaults.standard.bool(forKey: K.isPremium) || Int.random(in: 1...2)==2) {
                        NotificationCenter.default.post(Notification(name: .shouldPlaceAd, object: nil, userInfo: nil))
                    } else {
                        addChild(gameOverLabel)
                    }
                    
                } else {
                    if K.appDelegate.birdRewardedAd?.isReady==true && !jumpAd && !BirdViewController.hasSucceeded && ([1,2,3].randomElement() ?? 2)==2 {
                        NotificationCenter.default.post(Notification(name: .shouldPlaceAd, object: nil, userInfo: nil))
                    } else {
                        addChild(gameOverLabel)
                    }
                    
                    if K.appDelegate.birdRewardedAd?.isReady != true {
                        K.appDelegate.birdRewardedAd = K.appDelegate.createAndLoadReward(id: K.birdRewardedAdUnitID)
                    }
                }
                
                jumpAd = false
            }
        }
    }

    func makePipe1(_ moveAndRemovePipes: SKAction, _ gapHeight: CGFloat, _ pipeOffset: CGFloat) {
        let pipeTexture = SKTexture(imageNamed: "pipe1")
        let pipe1 = SKSpriteNode(texture: pipeTexture)
        pipe1.position = CGPoint(
            x: self.frame.midX + self.frame.width,
            y: self.frame.midY + pipeTexture.size().height / 2 + gapHeight / 2 + pipeOffset
        )
        pipe1.run(moveAndRemovePipes)

        pipe1.physicsBody = SKPhysicsBody(rectangleOf: pipeTexture.size())
        pipe1.physicsBody!.isDynamic = false

        pipe1.physicsBody!.contactTestBitMask = ColliderType.Object.rawValue
        pipe1.physicsBody!.categoryBitMask = ColliderType.Object.rawValue
        pipe1.physicsBody!.collisionBitMask = ColliderType.Object.rawValue
        setPipePosition(pipe1)

        self.addChild(pipe1)
    }

    func makePipe2(_ moveAndRemovePipes: SKAction, _ gapHeight: CGFloat, _ pipeOffset: CGFloat) {
        let pipe2Texture = SKTexture(imageNamed: "pipe2")
        let pipe2 = SKSpriteNode(texture: pipe2Texture)
        pipe2.position = CGPoint(
            x: self.frame.midX + self.frame.width,
            y: self.frame.midY - pipe2Texture.size().height / 2 - gapHeight / 2  + pipeOffset
        )
        pipe2.run(moveAndRemovePipes)

        pipe2.physicsBody = SKPhysicsBody(rectangleOf: pipe2Texture.size())
        pipe2.physicsBody!.isDynamic = false

        pipe2.physicsBody!.contactTestBitMask = ColliderType.Object.rawValue
        pipe2.physicsBody!.categoryBitMask = ColliderType.Object.rawValue
        pipe2.physicsBody!.collisionBitMask = ColliderType.Object.rawValue
        setPipePosition(pipe2)

        self.addChild(pipe2)
    }

    // Set the pipe second position after background
    func setPipePosition(_ pipe: SKSpriteNode) {
        pipe.zPosition = -1
    }

    func makeGap(_ moveAndRemovePipes: SKAction, _ gapHeight: CGFloat, _ pipeOffset: CGFloat) {
        let pipeTexture = SKTexture(imageNamed: "pipe1.png")

        let gap = SKNode()
        gap.position = CGPoint(x: self.frame.midX + self.frame.width, y: self.frame.midY + pipeOffset)
        gap.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: pipeTexture.size().width, height: gapHeight))

        gap.physicsBody!.isDynamic = false
        gap.run(moveAndRemovePipes)

        gap.physicsBody!.contactTestBitMask = ColliderType.Bird.rawValue
        gap.physicsBody!.categoryBitMask = ColliderType.Gap.rawValue
        gap.physicsBody!.collisionBitMask = ColliderType.Gap.rawValue

        self.addChild(gap)
    }

    func makeGround() {
        let ground = SKNode()
        ground.position = CGPoint(x: self.frame.midX, y: -self.frame.height / 2)
        ground.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: self.frame.width, height: 1))

        ground.physicsBody!.isDynamic = false

        ground.physicsBody!.contactTestBitMask = ColliderType.Object.rawValue
        ground.physicsBody!.categoryBitMask = ColliderType.Object.rawValue
        ground.physicsBody!.collisionBitMask = ColliderType.Object.rawValue

        self.addChild(ground)
    }

    func setMessageScoreStyle() {
        gameOverLabel.fontName = "Futura"
        gameOverLabel.fontSize = 50
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        NotificationCenter.default.post(Notification(name: .didTouch))
        if !GameScene.movedToGame {return}
        
        NotificationCenter.default.post(Notification(name: .whetherShowBest, object: false, userInfo: nil))
        if gameOver {
            BirdViewController.hasSucceeded = false
            startGame()
            removeAllChildren()
            initializeGame()
        } else {
            bird.physicsBody!.isDynamic = true
            bird.physicsBody!.velocity = CGVector(dx: 0, dy: 0)
            bird.physicsBody!.applyImpulse(CGVector(dx: 0, dy: 70))
        }
    }
    
    func startGame() {
        gameOver = false
        if BirdViewController.isEarned {
            jumpAd = true
            score = BirdViewController.prevScore
        } else {
            score = 0
        }
        self.speed = 1
        
        NotificationCenter.default.post(Notification(name: .didUpdatePoint, object: score, userInfo: nil))
    }

    func resetGame() {
        self.speed = 0
        gameOver = true
        timer.invalidate()
        
        NotificationCenter.default.post(Notification(name: .whetherShowBest, object: true, userInfo: nil))
    }

    @objc func continueGame() {
        startGame()
        removeAllChildren()
        initializeGame()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
