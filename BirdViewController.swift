//
//  BirdViewController.swift
//  Flaffy Bird
//
//  Created by Jintian Wang on 2020/3/10.
//  Copyright © 2020 Jintian Wang. All rights reserved.
//

import UIKit
import SpriteKit
import GameplayKit
import AVFoundation
import ChameleonFramework
import GoogleMobileAds
import FirebaseAnalytics

class BirdViewController: UIViewController, GADRewardedAdDelegate {

    @IBOutlet var speakerButton: UIButton!
    @IBOutlet var tipLabel: UILabel!
    @IBOutlet var topView: UIView!
    @IBOutlet var progressBar: UIProgressView!
    @IBOutlet var pointLabel: UILabel!
    @IBOutlet var bestScoreLabel: UILabel!
    @IBOutlet var goalLabel: UILabel!
    @IBOutlet var succeedTopLabel: UILabel!
    @IBOutlet var exitButton: UIButton!
    @IBOutlet var idleProgressBar: UIProgressView!
    
    @IBOutlet var overlayView: UIView!
    @IBOutlet var easyLabel: UILabel!
    @IBOutlet var tapToStartLabel: UILabel!
    
    @IBOutlet var adsNotReadyLabel: UILabel!
    @IBOutlet var adView: UIView!
    @IBOutlet var adImageView: UIImageView!
    @IBOutlet var rewardLabel: UILabel!
    @IBOutlet var yesButton: UIButton!
    @IBOutlet var noButton: UIButton!
    
    private var backPlayer: AVAudioPlayer!
    
    static var isEarned = false
    
    static var prevScore = 0
    
    private var easyTimer: Timer?
    private var idleTimer: Timer?
    
    private var idleTimeLeft = 15 {
        didSet {
            if isFromMission {return}
            
            idleProgressBar.setProgress(Float(idleTimeLeft)/15.0, animated: true)
            if idleTimeLeft <= 0 {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    private var realTimePassed = 0
    static var hasSucceeded = false
    var isFromMission = false
    var goal = 5
    
    static var bk = String()
    
    private var isPremium = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //isPremium = UserDefaults.standard.bool(forKey: K.isPremium)
        isPremium = true
        
        if isPremium {
            noButton.removeFromSuperview()
            rewardLabel.text = "AN EXTRA LIFE FOR THIS ROUND?".localized
        } else {
            K.appDelegate.birdRewardedAd = K.appDelegate.createAndLoadReward(id: K.birdRewardedAdUnitID)
        }
        
        tipLabel.isHidden = isFromMission
        
        idleProgressBar.transform = CGAffineTransform(scaleX: 1, y: 2)
        
        pointLabel.text = "\("Current".localized): 0"
        bestScoreLabel.text = "\("Best Score".localized): \(UserDefaults.standard.integer(forKey: K.birdBestScore))"
        bestScoreLabel.isHidden = false
        
        BirdViewController.bk = ["bk1","bk2","bk3"].randomElement() ?? "bk3"
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleUpdatePoint(notification:)), name: .didUpdatePoint, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAdNoti), name: .shouldPlaceAd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resetIdle), name: .didTouch, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(whetherShowBestLabel(notification:)), name: .whetherShowBest, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNewRecord(notification:)), name: .didOccurNewRecord, object: nil)

        progressBar.setProgress(0.01, animated: true)
        setCorner()
        goalLabel.text = "\("Goal".localized): \(goal)"
        
        waitAnimation()
        
        presentGame()
        setBackgroundMusic()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleMovedToBack), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    func setBackgroundMusic() {
        speakerButton.tintColor = BirdViewController.bk != "bk1" ? .darkGray : .white
        if UserDefaults.standard.bool(forKey: K.noGameSound) {
            speakerButton.setImage(UIImage(systemName: "speaker.slash.fill"), for: .normal)
        } else {
            speakerButton.setImage(UIImage(systemName: "speaker.1.fill"), for: .normal)
            playBackMusic()
        }
    }
    
    func playBackMusic() {
        let url = Bundle.main.url(forResource: "birdBack", withExtension: "mp3")
        if let url = url {
            do {
                backPlayer = try AVAudioPlayer(contentsOf: url)
                backPlayer.play()
                backPlayer.numberOfLoops = -1
            } catch {
            }
        }
    }
    
    @IBAction func speakerTapped(_ sender: UIButton) {
        if UserDefaults.standard.bool(forKey: K.noGameSound) {
            UserDefaults.standard.set(false, forKey: K.noGameSound)
            speakerButton.setImage(UIImage(systemName: "speaker.1.fill"), for: .normal)
            if backPlayer != nil {
                backPlayer.play()
            } else {
                playBackMusic()
            }
        } else {
            UserDefaults.standard.set(true, forKey: K.noGameSound)
            speakerButton.setImage(UIImage(systemName: "speaker.slash.fill"), for: .normal)
            backPlayer.pause()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        topView.backgroundColor = UIColor(gradientStyle: .topToBottom, withFrame: topView.bounds, andColors: [#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.6),#colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)])
    }
    
    @objc func handleMovedToBack() {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @objc func handleNewRecord(notification: Notification) {
        if let bestScore = notification.object as? Int {
            UserDefaults.standard.set(bestScore, forKey: K.birdBestScore)
            bestScoreLabel.text = "\("Best Score".localized): \(bestScore)"
        }
    }
    
    @objc func whetherShowBestLabel(notification: Notification) {
        if let showOrNot = notification.object as? Bool {
            bestScoreLabel.isHidden = !showOrNot
        }
    }
    
    @objc func resetIdle() {
        idleTimeLeft = 15
    }
    
    func  presentGame() {
        if let view = self.view as! SKView? {
            if let scene = SKScene(fileNamed: "GameScene") {
                scene.scaleMode = .aspectFill
                view.presentScene(scene)
            }
            view.ignoresSiblingOrder = true
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        if backPlayer != nil {backPlayer.stop()}
        BirdViewController.hasSucceeded = false
        GameScene.movedToGame = false
        idleTimer?.invalidate()
        idleTimer = nil
        easyTimer?.invalidate()
        easyTimer = nil
    }
    
    @objc func handleUpdatePoint(notification: Notification) {
        if let score = notification.object as? Int {
            pointLabel.text = "\("Current".localized): \(score)"
            progressBar.setProgress(score==0 ? 0.01 : Float(score)/Float(goal), animated: true)
            
            if score == 0 {succeedTopLabel.alpha = 0}
            if score == goal {
                
                if goal == Bird.levels[5].goal {
                    UserDefaults.standard.set(true, forKey: K.birdUnlocked)
                }
                
                showExit()
                BirdViewController.hasSucceeded = true
                self.succeedTopLabel.transform = CGAffineTransform(translationX: 0, y: 150)
                UIView.animate(withDuration: 0.3, animations: {
                    self.succeedTopLabel.alpha = 1
                    self.succeedTopLabel.transform = CGAffineTransform(translationX: 0, y: -20)
                }) { (_) in
                    self.succeedTopLabel.transform = CGAffineTransform.identity
                }
            }
        }
    }
    
    @objc func handleAdNoti() {
        adView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        overlayView.isUserInteractionEnabled = false
        GameScene.movedToGame = false
        easyLabel.isHidden = true
        UIView.animate(withDuration: 0.15) {
           self.adView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.adView.alpha = 1
            self.adImageView.alpha = 1
            self.overlayView.alpha = 1
        }
        UIView.animate(withDuration: 0.05, delay: 0.2, options: .curveLinear, animations: {
            self.adView.transform = CGAffineTransform.identity
        }, completion: nil)
    }
    
    @objc func viewTapped() {
        turnedPink = false
        exitButton.backgroundColor = #colorLiteral(red: 1, green: 0.1764705882, blue: 0.3333333333, alpha: 0.3)
    }
    
    @IBAction func yesTapped(_ sender: UIButton) {
        idleTimeLeft = 15
        if isPremium {
            BirdViewController.isEarned = true
            BirdViewController.hasSucceeded = false
            noTapped(nil)
            
        } else {
            K.appDelegate.birdRewardedAd?.present(fromRootViewController: self, delegate: self)
            bestScoreLabel.isHidden = true
            UIView.animate(withDuration: 0.2) {
                self.adView.alpha = 0
                self.adImageView.alpha = 0
                self.overlayView.alpha = 0
            }
        
            log()
        }
    }
    
    func log() {
        Analytics.logEvent("bird_rewardedAd_entered", parameters: [
            "click_time": "\(Date())",
            "l": UserDefaults.standard.string(forKey: K.r) ?? "Unknown..."
        ])
    }

    func rewardedAd(_ rewardedAd: GADRewardedAd, userDidEarn reward: GADAdReward) {
        BirdViewController.isEarned = true
        BirdViewController.hasSucceeded = false
    }
    
    func rewardedAdDidDismiss(_ rewardedAd: GADRewardedAd) {
        K.appDelegate.birdRewardedAd = K.appDelegate.createAndLoadReward(id: K.birdRewardedAdUnitID)
        idleTimeLeft = 15
        openIdleTimer()
        
        GameScene.movedToGame = true
        NotificationCenter.default.post(Notification(name: .continueGame))
    }
    
    func rewardedAd(_ rewardedAd: GADRewardedAd, didFailToPresentWithError error: Error) {
        animateFail(with: adsNotReadyLabel)
    }
    
    func animateFail(with label: UILabel) {
        label.transform = CGAffineTransform(translationX: 0, y: 150)
        UIView.animate(withDuration: 0.2, animations: {
            label.alpha = 0.8
            label.transform = CGAffineTransform(translationX: 0, y: -10)
            self.overlayView.alpha = 0
        }) { (_) in
            label.transform = CGAffineTransform.identity
            NotificationCenter.default.post(Notification(name: .continueGame))
        }
    }
    
    @IBAction func noTapped(_ sender: Any?) {
        idleTimeLeft = 15
        bestScoreLabel.isHidden = true
        GameScene.movedToGame = true
        NotificationCenter.default.post(Notification(name: .continueGame))
        UIView.animate(withDuration: 0.2) {
            self.adView.alpha = 0
            self.adImageView.alpha = 0
            self.overlayView.alpha = 0
        }
    }
    
    private var turnedPink = true
    @IBAction func exitTapped(_ sender: UIButton) {
        idleTimeLeft = 15
        if isFromMission {
            if turnedPink {
                NotificationCenter.default.removeObserver(self)
                ARMissionViewController.backFromGame = true
                UserDefaults.standard.set(UserDefaults.standard.integer(forKey: K.interstitialCount) + 1, forKey: K.interstitialCount)
                performSegue(withIdentifier: K.exitFromBirdToMission, sender: self)
            } else {
                sender.backgroundColor = .systemPink
                turnedPink = true
            }
        } else {
            NotificationCenter.default.removeObserver(self)
            performSegue(withIdentifier: K.birdToPicSegue, sender: self)
        }
    }
    
    func setCorner() {
        easyLabel.layer.cornerRadius = easyLabel.bounds.width / 2
        succeedTopLabel.layer.cornerRadius = 5
        
        adsNotReadyLabel.layer.cornerRadius = 12
        adsNotReadyLabel.layer.borderWidth = 2
        adsNotReadyLabel.layer.borderColor = UIColor.white.cgColor
        adView.layer.cornerRadius = 12
        adView.layer.borderWidth = 2
        adView.layer.borderColor = #colorLiteral(red: 0.9824988246, green: 0.7339295745, blue: 0.06266329437, alpha: 1).cgColor
        
        yesButton.layer.cornerRadius = 8
        noButton.layer.cornerRadius = 8
        
        exitButton.layer.cornerRadius = 8
        exitButton.alpha = isFromMission ? 1 : 0
        idleProgressBar.isHidden = isFromMission ? true : false
    }
    
    
    func waitAnimation() {
        easyLabel.alpha = 1
        self.animateOneCircle()
        var circle = 0
        var openIdle = true
        let maxCircle = Int.random(in: 1...2)
        var gestureAdded = false
        easyTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true, block: { [weak self] (_) in
            
            guard let self = self else {return}
            
            if circle <= maxCircle {
                circle += 1
                self.animateOneCircle()
            } else {
                if !self.isFromMission && openIdle {
                    openIdle = false
                    self.openIdleTimer()
                }
                
                self.blinkTap()
                
                if !gestureAdded {
                    GameScene.movedToGame = true
                    self.overlayView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.beginGame)))
                    
                    if self.isFromMission {
                        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.viewTapped)))
                    }
                    
                    gestureAdded = true
                }
            }
        })
        easyTimer?.tolerance = 0.1
    }
    
    @objc func beginGame() {
        bestScoreLabel.isHidden = true
        GameScene.movedToGame = true
        idleTimeLeft = 15
    
        UIView.animate(withDuration: 0.5, animations: {
            self.overlayView.alpha = 0
        }) { (_) in
            self.easyTimer?.invalidate()
            self.easyTimer = nil
            self.tipLabel.isHidden = true
        }
    }
    
    func openIdleTimer() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (_) in
            self.idleTimeLeft -= 1
            self.realTimePassed += 1
            if self.realTimePassed == 20 {
                self.showExit()
            }
        })
        idleTimer?.tolerance = 0.1
    }
    
    func showExit() {
        if isFromMission {return}
        
        UIView.animate(withDuration: 0.3, animations: {
            self.exitButton.alpha = 1
            self.exitButton.backgroundColor = .systemPink
            self.turnedPink = true
        }) { (_) in
            UIView.animate(withDuration: 0.3) {
                self.idleProgressBar.transform = CGAffineTransform(translationX: 0, y: -(self.exitButton.bounds.height+20))
            }
        }
    }
    
    func blinkTap() {
        self.tapToStartLabel.alpha = 1
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.4) {
            self.tapToStartLabel.alpha = 0
        }
    }
    
    func animateOneCircle() {
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveLinear, animations: {
            self.easyLabel.transform = CGAffineTransform(rotationAngle: CGFloat.pi)
        }, completion: nil)
        UIView.animate(withDuration: 0.4, delay: 0.4, options: .curveLinear, animations: {
            self.easyLabel.transform = CGAffineTransform(rotationAngle: 2 * CGFloat.pi)
        }, completion: nil)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
