import SwiftUI

struct NumericEdit {
    let name: String
    let key: WritableKeyPath<Recipe, Double>
    let range: ClosedRange<Double>
    let unit: String
    var multiplier: Double { unit.isEmpty ? 100 : 1 }
    var displayRange: ClosedRange<Double> { (range.lowerBound * multiplier)...(range.upperBound * multiplier) }
    func parse(_ text: String) -> Double? {
        guard let number = Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",",with: ".")), number.isFinite, displayRange.contains(number) else { return nil }
        return number / multiplier
    }
}
@MainActor struct FramingGrid: View {
    let sourceSize: CGSize
    let recipe: Recipe
    var body: some View {
        Canvas { context,size in
            let framed = PhotoFraming.window(in: PhotoFraming.orientedSize(sourceSize,recipe: recipe),recipe: recipe).size
            let scale = min(size.width/framed.width,size.height/framed.height)
            let box = CGRect(x: (size.width-framed.width*scale)/2,y: (size.height-framed.height*scale)/2,width: framed.width*scale,height: framed.height*scale)
            var grid = Path()
            for index in 1...2 {
                let fraction = CGFloat(index)/3
                grid.move(to: CGPoint(x: box.minX+box.width*fraction,y: box.minY)); grid.addLine(to: CGPoint(x: box.minX+box.width*fraction,y: box.maxY))
                grid.move(to: CGPoint(x: box.minX,y: box.minY+box.height*fraction)); grid.addLine(to: CGPoint(x: box.maxX,y: box.minY+box.height*fraction))
            }
            context.stroke(grid,with: .color(.white.opacity(0.4)),lineWidth: 0.75)
            context.stroke(Path(box),with: .color(.white.opacity(0.7)),lineWidth: 1)
        }.accessibilityHidden(true)
    }
}
