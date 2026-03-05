import SwiftUI

struct IslandSmasherGameView: View {
    @Environment(\.dismiss) var dismiss
    
    // Game state
    @State private var ballPosition: CGPoint = .zero 
    @State private var ballVelocity: CGVector = .zero 
    @State private var paddlePositionX: CGFloat = .zero
    @State private var score = 0
    @State private var highScore = UserDefaults.standard.integer(forKey: "islandSmasherHighScore")
    @State private var isGameOver = false
    @State private var gameHasBeenInitialized = false
    @State private var lastUpdateTime: Date? = nil
    
    // Game constants
    let ballRadius: CGFloat = 12
    let paddleWidth: CGFloat = 100
    let paddleHeight: CGFloat = 30
    let dynamicIslandY: CGFloat = 50 
    let dynamicIslandHeight: CGFloat = 30
    let dynamicIslandWidth: CGFloat = 120
    let paddleCornerRadius: CGFloat = 5
    let paddleBounceNudgeUp: CGFloat = 1.0 

    let initialSpeedMagnitude: CGFloat = 3.5 // Increased from 2.5
    let speedIncrement: CGFloat = 0.35 // Increased from 0.25
    let scoreIntervalForSpeedIncrease: Int = 2 // Faster progression, every 2 points instead of 3
    let maxSpeedMagnitude: CGFloat = 8.0 // Slightly higher max speed

    let gameBackgroundColor = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.55, green: 0.73, blue: 0.55).opacity(0.8),
            Color(red: 0.55, green: 0.73, blue: 0.55),
            Color(red: 0.45, green: 0.63, blue: 0.45)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    let paddleGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.45, green: 0.63, blue: 0.45),
            Color(red: 0.35, green: 0.53, blue: 0.35)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    let islandGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.55, green: 0.73, blue: 0.55).opacity(0.9),
            Color(red: 0.55, green: 0.73, blue: 0.55)
        ]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    let ballGradient = RadialGradient(
        gradient: Gradient(colors: [
            Color.white.opacity(0.9),
            Color.orange,
            Color.red.opacity(0.8)
        ]),
        center: .topLeading,
        startRadius: 2,
        endRadius: 12
    )

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                SwiftUI.TimelineView(.animation) { timelineContext in
                    VStack(spacing: 0) {
                        Canvas { context, size in
                            
                            // Draw Island (Target)

                            let islandRect = CGRect(
                                x: (size.width - dynamicIslandWidth) / 2,
                                y: dynamicIslandY - dynamicIslandHeight / 2,
                                width: dynamicIslandWidth,
                                height: dynamicIslandHeight
                            )
                            
                            // Island shadow
                            let shadowRect = CGRect(
                                x: islandRect.minX + 2,
                                y: islandRect.minY + 2,
                                width: islandRect.width,
                                height: islandRect.height
                            )
                            context.fill(
                                Path(roundedRect: shadowRect, cornerRadius: dynamicIslandHeight / 2),
                                with: .color(Color.black.opacity(0.2))
                            )
                            
                            // Island body
                            context.fill(
                                Path(roundedRect: islandRect, cornerRadius: dynamicIslandHeight / 2),
                                with: .linearGradient(
                                    Gradient(colors: [Color(red: 0.55, green: 0.73, blue: 0.55).opacity(0.9), Color(red: 0.55, green: 0.73, blue: 0.55)]),
                                    startPoint: CGPoint(x: 0, y: 0),
                                    endPoint: CGPoint(x: 0, y: 1)
                                )
                            )
                            
                            // Island highlight
                            let highlightRect = CGRect(
                                x: islandRect.minX + 4,
                                y: islandRect.minY + 2,
                                width: islandRect.width - 8,
                                height: islandRect.height / 3
                            )
                            context.fill(
                                Path(roundedRect: highlightRect, cornerRadius: 8),
                                with: .color(Color.white.opacity(0.2))
                            )
                            
                            context.draw(
                                Text("TARGET")
                                    .font(.caption.bold())
                                    .foregroundColor(.white),
                                at: CGPoint(x: size.width / 2, y: dynamicIslandY)
                            )

                            // Draw Paddle with gradient and shadow
                            let paddleRect = CGRect(
                                x: paddlePositionX - paddleWidth / 2,
                                y: size.height - paddleHeight - 30,
                                width: paddleWidth,
                                height: paddleHeight
                            )
                            
                            // Paddle shadow
                            let paddleShadowRect = CGRect(
                                x: paddleRect.minX + 1,
                                y: paddleRect.minY + 2,
                                width: paddleRect.width,
                                height: paddleRect.height
                            )
                            context.fill(
                                Path(roundedRect: paddleShadowRect, cornerRadius: paddleCornerRadius),
                                with: .color(Color.black.opacity(0.15))
                            )
                            
                            // Paddle body
                            context.fill(
                                Path(roundedRect: paddleRect, cornerRadius: paddleCornerRadius),
                                with: .linearGradient(
                                    Gradient(colors: [Color(red: 0.45, green: 0.63, blue: 0.45), Color(red: 0.35, green: 0.53, blue: 0.35)]),
                                    startPoint: CGPoint(x: 0, y: 0),
                                    endPoint: CGPoint(x: 0, y: 1)
                                )
                            )
                            
                            // Paddle highlight
                            let paddleHighlight = CGRect(
                                x: paddleRect.minX + 4,
                                y: paddleRect.minY + 2,
                                width: paddleRect.width - 8,
                                height: 4
                            )
                            context.fill(
                                Path(roundedRect: paddleHighlight, cornerRadius: 2),
                                with: .color(Color.white.opacity(0.3))
                            )
                            
                            // Draw Ball with gradient and glow effect
                            if !ballPosition.equalTo(.zero) {
                                let ballRect = CGRect(
                                    x: ballPosition.x - ballRadius,
                                    y: ballPosition.y - ballRadius,
                                    width: ballRadius * 2,
                                    height: ballRadius * 2
                                )
                                
                                // Ball glow effect
                                let glowRect = CGRect(
                                    x: ballPosition.x - ballRadius - 2,
                                    y: ballPosition.y - ballRadius - 2,
                                    width: (ballRadius + 2) * 2,
                                    height: (ballRadius + 2) * 2
                                )
                                context.fill(
                                    Path(ellipseIn: glowRect),
                                    with: .color(Color.orange.opacity(0.3))
                                )
                                
                                // Ball body
                                context.fill(
                                    Path(ellipseIn: ballRect),
                                    with: .radialGradient(
                                        Gradient(colors: [
                                            Color.white.opacity(0.9),
                                            Color.orange,
                                            Color.red.opacity(0.8)
                                        ]),
                                        center: CGPoint(x: 0.3, y: 0.3),
                                        startRadius: 2,
                                        endRadius: CGFloat(ballRadius)
                                    )
                                )
                                
                                // Ball highlight
                                let highlightSize: CGFloat = 4
                                let highlightRect = CGRect(
                                    x: ballPosition.x - ballRadius/2,
                                    y: ballPosition.y - ballRadius/2,
                                    width: highlightSize,
                                    height: highlightSize
                                )
                                context.fill(
                                    Path(ellipseIn: highlightRect),
                                    with: .color(Color.white.opacity(0.6))
                                )
                            }
                        }
                        .overlay(gameOverOverlay(geometrySize: geometry.size))
                        .gesture(paddleDragGesture(geometrySize: geometry.size))
                        .onTapGesture { if isGameOver { resetGame(size: geometry.size) } }
                        .onChange(of: timelineContext.date) { oldValue, newDate in
                            updateGame(size: geometry.size, timelineDate: newDate)
                        }
                    }
                }
            }
            .background(gameBackgroundColor)
            .ignoresSafeArea(.container, edges: .bottom)
            .overlay(alignment: .top) { scoreDisplay }
            .onAppear {
                if !gameHasBeenInitialized {
                    resetGame(size: geometry.size)
                    gameHasBeenInitialized = true
                    lastUpdateTime = Date() 
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scoreDisplay: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Score")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                Text("\(score)")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Best")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                Text("\(highScore)")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.3),
                    Color.clear
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private func gameOverOverlay(geometrySize: CGSize) -> some View {
        if isGameOver {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Game Over!")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    
                    Text("Score: \(score)")
                        .font(.title2.weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    if score == highScore && score > 0 {
                        Text("🎉 New High Score! 🎉")
                            .font(.headline.weight(.medium))
                            .foregroundColor(.yellow)
                    }
                }
                
                Button("Play Again") { 
                    resetGame(size: geometrySize) 
                }
                .font(.headline.weight(.semibold))
                .foregroundColor(.green)
                .frame(width: 200, height: 50)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.45, green: 0.63, blue: 0.45),
                            Color(red: 0.35, green: 0.53, blue: 0.35)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(25)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color.black.opacity(0.7)
                    .blur(radius: 1)
            )
        }
    }

    private func paddleDragGesture(geometrySize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !isGameOver {
                    self.paddlePositionX = value.location.x
                    self.paddlePositionX = max(paddleWidth / 2, min(geometrySize.width - paddleWidth / 2, self.paddlePositionX))
                }
            }
    }

    func updateGame(size: CGSize, timelineDate: Date) {
        guard !isGameOver, size.width > 0, size.height > 0 else { return }

        let newX = ballPosition.x + ballVelocity.dx
        let newY = ballPosition.y + ballVelocity.dy
        ballPosition = CGPoint(x: newX, y: newY)
        
        let ballRect = CGRect(x: ballPosition.x - ballRadius, y: ballPosition.y - ballRadius, width: ballRadius * 2, height: ballRadius * 2)

        if ballRect.minX <= 0 || ballRect.maxX >= size.width {
            ballVelocity.dx *= -1
            ballPosition.x = max(ballRadius, min(size.width - ballRadius, ballPosition.x)) 
        }
        if ballRect.minY <= 0 {
            ballVelocity.dy *= -1
            ballPosition.y = ballRadius
        }
        
        let visualPaddleMinY = size.height - paddleHeight - 30
        let paddleHitboxWidth = paddleWidth - 2 * paddleCornerRadius 
        let sensitiveHitboxHeight: CGFloat = 1.0

        let paddleHitboxRect = CGRect(
            x: paddlePositionX - paddleHitboxWidth / 2,
            y: visualPaddleMinY,                         
            width: paddleHitboxWidth,                    
            height: sensitiveHitboxHeight                
        )

        if ballRect.intersects(paddleHitboxRect) && ballVelocity.dy > 0 {
            ballVelocity.dy *= -1
            ballPosition.y = visualPaddleMinY - ballRadius - paddleBounceNudgeUp 
        }
        
        let islandHitBox = CGRect(
            x: (size.width - dynamicIslandWidth) / 2,
            y: dynamicIslandY - dynamicIslandHeight / 2,
            width: dynamicIslandWidth,
            height: dynamicIslandHeight
        )
        if ballRect.intersects(islandHitBox) {
            score += 1
            if score > highScore {
                highScore = score
                UserDefaults.standard.set(highScore, forKey: "islandSmasherHighScore")
            }
            ballVelocity.dy *= -1 
            ballPosition.y = islandHitBox.maxY + ballRadius

            if score > 0 && score % scoreIntervalForSpeedIncrease == 0 {
                let currentSpeedDx = abs(ballVelocity.dx)
                let currentSpeedDy = abs(ballVelocity.dy)

                if currentSpeedDx < maxSpeedMagnitude {
                    ballVelocity.dx += copysign(speedIncrement, ballVelocity.dx)
                }
                if currentSpeedDy < maxSpeedMagnitude {
                    ballVelocity.dy += copysign(speedIncrement, ballVelocity.dy)
                }
            }
        }

        if ballRect.minY > size.height { 
            isGameOver = true
        }
    }
    
    func resetGame(size: CGSize) {
        if size.width > 0 && size.height > 0 {
            ballPosition = CGPoint(x: size.width / 2, y: size.height / 3)
            paddlePositionX = size.width / 2
        } else {
            let fallbackWidth: CGFloat = 390 
            let fallbackHeight: CGFloat = 700 
            ballPosition = CGPoint(x: fallbackWidth / 2, y: fallbackHeight / 3)
            paddlePositionX = fallbackWidth / 2
        }
        
        let angle = CGFloat.random(in: (CGFloat.pi / 4)...(3 * CGFloat.pi / 4)) 
        ballVelocity = CGVector(dx: initialSpeedMagnitude * cos(angle), dy: -initialSpeedMagnitude * sin(angle))
        if ballVelocity.dy > 0 {
            ballVelocity.dy *= -1
        }
        if Bool.random() {
            ballVelocity.dx *= -1
        }

        score = 0
        isGameOver = false
    }
}