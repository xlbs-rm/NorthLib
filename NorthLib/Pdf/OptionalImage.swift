//
//  OptionalImage.swift
//  NorthLib
//
//  Created by Ringo Müller-Gromes on 06.11.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import PDFKit

struct ZoomedPdfImageSpecConstants {
  static let maxRenderingZoom:CGFloat = 6.0
}


// MARK: - ZoomedPdfImageSpec : OptionalImage (Protocol)
public protocol ZoomedPdfImageSpec : OptionalImage {
  var sectionTitle: String? { get set}
  var pageTitle: String? { get set}
  var pdfUrl: URL? { get }
  var pdfPageIndex: Int? { get }
  var renderingStoped: Bool { get }
  var nextZoomStep: CGFloat { get }
  
  var canRequestHighResImg: Bool { get }
  var nextRenderingZoomScale: CGFloat { get }
  
  func renderImageWithNextScale(finishedCallback: ((Bool) -> ())?)
  func renderFullscreenImageIfNeeded(finishedCallback: ((Bool) -> ())?)
  func renderImageWithScale(scale: CGFloat, finishedCallback: ((Bool) -> ())?)
}

extension ZoomedPdfImageSpec{
  public var canRequestHighResImg: Bool {
    get {
      return nextRenderingZoomScale <= ZoomedPdfImageSpecConstants.maxRenderingZoom
    }
  }
  
  public func renderImageWithNextScale(finishedCallback: ((Bool) -> ())?){
    renderImageWithScale(scale: self.nextRenderingZoomScale, finishedCallback:finishedCallback)
  }
}

public class ZoomedPdfImage: OptionalImageItem, ZoomedPdfImageSpec {
  public var sectionTitle: String?
  public var pageTitle: String?
  public private(set) var pdfUrl: URL?
  public private(set) var pdfPageIndex: Int?
  
  convenience init(url:URL?, index:Int) {
    self.init()
    self.pdfUrl = url
    self.pdfPageIndex = index
  }
    
  var calculatedNextScreenZoomScale: CGFloat?
  
  public var nextRenderingZoomScale: CGFloat {
    get{
      if calculatedNextScreenZoomScale == nil {
        calculatedNextScreenZoomScale = calculateNextScreenZoomScale
      }
      return calculatedNextScreenZoomScale!
    }
  }
  
  public override weak var image: UIImage? {
    willSet{
      print("ZoomedPdfImage image set at \(calculatedNextScreenZoomScale ?? 0)x")
    }
    didSet{
      calculatedNextScreenZoomScale = nil
    }
  }
  
  //want screen zoom scales 1, 4, 8, 12...
  var calculateNextScreenZoomScale: CGFloat {
    get{
      guard let img = self.image else { return 1.0 }
      let currentScale = img.size.width/UIScreen.main.nativeBounds.width
      
      switch currentScale {
        case _ where currentScale <= 1.0:
          return 3.0
        case _ where currentScale <= 3.0:
          return 6.0
        default:
          return ZoomedPdfImageSpecConstants.maxRenderingZoom
      }
    }
  }
  
  public var nextZoomStep: CGFloat {
    get {
      ///Usually a ratio between current and next but issues with division by 0 and expensive cals use simple switch
      /// Expect 3,6,max == 8
      if nextRenderingZoomScale == 3.0 { return 3.0 }
      else if nextRenderingZoomScale == 6.0 { return 8/6 }
      return 2.0
    }
  }
  
  public var renderingStoped = false
  
  public private(set) var pageDescription: String = ""
    
  public func renderFullscreenImageIfNeeded(finishedCallback: ((Bool) -> ())?) {
    self.renderImageWithScale(scale:1.0, finishedCallback: finishedCallback)
  }
  
  public func renderImageWithScale(scale: CGFloat, finishedCallback: ((Bool) -> ())?) {
    //Prevent Multiple time max rendering
    if scale > ZoomedPdfImageSpecConstants.maxRenderingZoom {
      return
    }
    let baseWidth = UIScreen.main.bounds.width*UIScreen.main.scale
    print("Optional Image, render Image with scale: \(scale) is width: \(baseWidth*scale) 1:1 image width should be: \(baseWidth)")
    PdfRenderService.render(item: self,
                            width: baseWidth*scale) { img in
      onMain { [weak self] in
        guard let self = self else { return }
        guard let newImage = img else { finishedCallback?(false); return }
        if self.renderingStoped { return }
        self.image = newImage
        finishedCallback?(true)
      }
    }
  }
  
  public func stopRendering(){
    self.renderingStoped = true
    self.image = nil
   
  }
  
  
}