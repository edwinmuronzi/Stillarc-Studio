import CoreImage

/// Small immutable sampling grid. Source suggestions run on request, never in preview rendering.
struct CleanupSource:Sendable {
    let pixels:[Float]
    let width:Int
    let height:Int
    init(_ image:CIImage) {
        width=128;height=128
        let e=image.extent,tiny=image.transformed(by:.init(translationX:-e.minX,y:-e.minY)).transformed(by:.init(scaleX:128/e.width,y:128/e.height))
        var data=[Float](repeating:0,count:128*128*4)
        ImageEngine.context().render(tiny,toBitmap:&data,rowBytes:128*16,bounds:CGRect(x:0,y:0,width:128,height:128),format:.RGBAf,colorSpace:ImageEngine.working);pixels=data
    }
    func suggestion(at target:CGPoint,radius:Double)->CGPoint? {
        guard target.x.isFinite,target.y.isFinite else {return nil}
        let tx=Int(target.x*Double(width)),ty=Int((1-target.y)*Double(height)),r=max(2,Int(radius*128))
        func stats(_ x:Int,_ y:Int,ring:Bool)->([Double],Double)? {
            var sums=[Double](repeating:0,count:3),squared=0.0,n=0.0
            let outer=ring ? r*2:r
            guard x-outer>=0,y-outer>=0,x+outer<width,y+outer<height else {return nil}
            for dy in stride(from:-outer,through:outer,by:2) {for dx in stride(from:-outer,through:outer,by:2) {
                let d=dx*dx+dy*dy;guard d<=outer*outer,(!ring || d>=r*r) else {continue}
                let i=((y+dy)*width+x+dx)*4
                guard pixels[i].isFinite,pixels[i+1].isFinite,pixels[i+2].isFinite,pixels[i+3]>0.9 else {continue}
                for c in 0..<3 {let v=Double(pixels[i+c]);sums[c]+=v;squared+=v*v};n+=1
            }}
            guard n>=4 else {return nil};let mean=sums.map {$0/n};return (mean,max(0,squared/(n*3)-mean.map {$0*$0}.reduce(0,+)/3))
        }
        guard let targetStats=stats(tx,ty,ring:true) else {return nil}
        var best:(Double,Int,Int)?
        let reach=min(48,max(12,r*8)),step=max(3,r)
        for y in stride(from:max(r,ty-reach),through:min(height-r-1,ty+reach),by:step) {for x in stride(from:max(r,tx-reach),through:min(width-r-1,tx+reach),by:step) {
            let distance=hypot(Double(x-tx),Double(y-ty));guard distance>Double(r)*2.2,let candidate=stats(x,y,ring:false) else {continue}
            let color=zip(candidate.0,targetStats.0).reduce(0){$0+pow($1.0-$1.1,2)}
            let score=color+candidate.1*0.3+distance/128*0.005
            if best == nil || score<best!.0 {best=(score,x,y)}
        }}
        guard let best else {return nil};return CGPoint(x:(Double(best.1)+0.5)/128,y:1-(Double(best.2)+0.5)/128)
    }
}
