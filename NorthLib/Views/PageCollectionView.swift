//
//  PageCollectionView.swift
//
//  Created by Norbert Thies on 09.07.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

/**
 A PageCollectionView (PCV) is a UICollectionView subclass presenting a number of 
 views in a horizontal row (like a row of pages).
 
 The PCV presents a list of views (called pages) that are scrollable horizontally. 
 Its width determines the width of the pages which all have the same width:
   - let cwidth be the width of the collection view
   - let relativeInset (adjustable) be a factor to cwidth which defines the 
     spacing between pages
   - then the spacing swidth = relativeInset * cwidth
   - let relativePageWidth (adjustable) be a factor to cwidth which defines the 
     width of a page
   - then the page width pwidth = relativePageWidth * cwidth
   - the page is pinned to the horizontal dimensions specified with these relative
     mesasures and centered vertically in the height of the collection view.
   - The page itself should either have been pinned to a height or to an aspect ratio
   - The first and last pages are inset as follows:
       inset = (cwidth - pwidth) / 2
 
 By default the PCV uses a UICollectionViewFlowLayout but you may specify any
 FlowLayout subclass using the initializer.

 PCV.isPagingEnabled = true may be used to get a paging like effect when scrolling, 
 ie. slowly scrolling from one page to the other. 
 If PCV.isPagingEnabled == false then also a page is centered in the PCV's view
 but it will be that view that would be near the center when the scrolling would 
 have come to a stop. This is a more fluent paging effect.
 */
open class PageCollectionView: UICollectionView, UICollectionViewDelegate, 
  UICollectionViewDataSource, UIScrollViewDelegate, UICollectionViewDelegateFlowLayout {
  
  /// relative spacing between pages (in relation to the Carousel's width)
  open var relativeSpacing: CGFloat = 0.12
  /// relative width of one page (in relation to the Carousel's width)
  open var relativePageWidth: CGFloat = 0.6
  /// width of collection view
  open var cwidth: CGFloat { return bounds.size.width }
  /// width of page
  open var pwidth: CGFloat { return cwidth * relativePageWidth }
  /// width of spacing
  open var swidth: CGFloat { return cwidth * relativeSpacing }
  /// width of cell incl. spacing
  open var cellWidth: CGFloat { return pwidth + swidth }
  /// inset of first/last page
  open var inset: CGFloat { return (cwidth - pwidth) / 2 }
  
  /// scroll from left to right or vice versa
  open var scrollFromLeftToRight: Bool = false {
    didSet { 
      if scrollFromLeftToRight {
        transform = CGAffineTransform(rotationAngle: CGFloat.pi)
      }
      else { transform = .identity }
      reloadData()
    }
  }
  
  fileprivate static var countView = 0  // #PageCollectionViews instantiated
  fileprivate static var reuseIdent: String = 
    { countView += 1; return "PCV\(countView)" }()
  
  /// The collection view cell to present in a page like fashion
  class PageCell: UICollectionViewCell {
    /// The page to display
    var page: OptionalView?
    /// The view to display
    var pageView: UIView? { return page?.activeView }
    
    /// Request view from provider and put it into a PageCell
    func update(pcv: PageCollectionView, idx: Int) {
      if let provider = pcv.provider {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        let page = provider(idx, self.page)
        let isAvailable = page.isAvailable
        page.activeView.addBorder(UIColor.yellow.withAlphaComponent(0.5), 5)
        if pcv.scrollFromLeftToRight {
          page.activeView.transform
            = CGAffineTransform(rotationAngle: -CGFloat.pi)
        }
        else {
          page.activeView.transform
            = .identity
        }

        contentView.addSubview(page.activeView)
        pin(page.activeView, to: contentView)
        self.page = page

        if isAvailable {
          page.loadView()
        }
        else {
          let iPath = IndexPath(item: idx, section: 0)
          page.whenAvailable { pcv.reloadItems(at: [iPath]) }
        }
      }
    }
    
    override init(frame: CGRect) {
      super.init(frame: frame)
      self.addBorder(UIColor.red.withAlphaComponent(0.8), 1)
      self.contentView.addBorder(UIColor.blue.withAlphaComponent(0.5), 3)
    }
    required init?(coder: NSCoder) {
      super.init(coder: coder)
    }
  } // PageCell
  
  // A closure providing the optional views to display
  public var provider: ((Int, OptionalView?)->OptionalView)? = nil
  
  /// Defines the closure which delivers the views to display
  open func viewProvider(provider: @escaping (Int, OptionalView?)->OptionalView) {
    self.provider = provider
  }
    
  // Setup the PCV
  private func setup() {
    guard let layout = self.collectionViewLayout as? UICollectionViewFlowLayout
      else { return }
    backgroundColor = UIColor.clear
    contentInsetAdjustmentBehavior = .never
    register(PageCell.self, forCellWithReuseIdentifier: PageCollectionView.reuseIdent)
    layout.scrollDirection = .horizontal
    delegate = self
    dataSource = self
    if scrollFromLeftToRight {
      transform = CGAffineTransform(rotationAngle: CGFloat.pi)
    }
  }
  
  public init(frame: CGRect, layout: UICollectionViewFlowLayout = 
    UICollectionViewFlowLayout()) {
    super.init(frame: frame, collectionViewLayout: layout)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  public convenience init() { self.init(frame: CGRect()) }
  
  fileprivate var _index: Int?
  fileprivate var isInitialized = false
  fileprivate var initialIndex: Int? = nil
  fileprivate var collectionViewInitialized = false
  
  // initialize with initialIndex when scroll view is ready
  fileprivate func initialize(_ itemIndex: Int? = nil) {
    guard let layout = self.collectionViewLayout as? UICollectionViewFlowLayout 
      else { return }
    if !isInitialized {
      layout.minimumLineSpacing = swidth
      layout.sectionInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
      isHidden = true 
      delay(seconds: 0.01) { [weak self] in//ToDo there is a better way!
        guard let self = self else { return }
        self.isInitialized = true
        if let idx = self.initialIndex { self.index = idx }
        self.isHidden = false
      }
    }
  }
  
  /// Returns the optional view at a given index (if that view is visible)
  open func optionalView(at idx: Int) -> OptionalView? {
    if let cell = cellForItem(at: IndexPath(item: idx, section: 0)) as? PageCell {
      return cell.page
    }
    else { return nil }
  }
  
  /// Index of current page, change it to scroll to a certain cell
  open var index: Int? {
    get { return _index }
    set(idx) { 
      if let idx = idx, idx != _index { 
        if isInitialized {
          scrollto(idx)
          callOnDisplay(idx: idx, oview: optionalView(at: idx))
        }
        else { initialIndex = idx }
      } 
    }
  }
  
  fileprivate var _count: Int = 0
  
  /// Define and change the number of views to display, will reload data
  open var count: Int {
    get { return _count }
    set { 
      _count = newValue
      reloadData()
    }
  }
  
  /// Insert a new page at (in front of) a given index
  open func insert(at idx: Int) {
    _count += 1
    if collectionViewInitialized {
      let ipath = IndexPath(item: idx, section: 0)
      insertItems(at: [ipath])
    }
  }
  
  /// Reload a single view
  open func reload(index: Int) { reloadItems(at: [IndexPath(item: index, section: 0)]) }
  
  // An array of closures, each is to call when the displayed page changes
  fileprivate var onDisplayClosures: [(Int, OptionalView?)->()] = []
   
  /// Define closure to call when a cell is newly displayed  
  public func onDisplay(closure: @escaping (Int, OptionalView?)->()) {
    onDisplayClosures += closure
  }
  
  // closure to execute on end display
  fileprivate var onEndDisplayClosures: [(Int, OptionalView?)->()] = []
  
  /// Define closure to call when a cell is not displayed
  public func onEndDisplayCell(closure: @escaping (Int, OptionalView?)->()) {
    onEndDisplayClosures += closure
  }
  
  public func collectionView(_ collectionView: UICollectionView,
                             didEndDisplaying cell: UICollectionViewCell,
                             forItemAt indexPath: IndexPath) {
    guard let pageCell = cell as? PageCell else {
      return
    }
    for cl in onEndDisplayClosures {
      cl(indexPath.row, pageCell.page)
    }
  }

  /// Call all onDisplay closures
  fileprivate func callOnDisplay(idx: Int, oview: OptionalView?) 
    { for cl in onDisplayClosures { cl(idx, oview) } }
  
  // updateDisplaying is called when the scrollview has been scrolled which
  // might have changed the view currently visible
  private func updateDisplaying(_ idx: Int) { 
    if _index != idx {
      _index = idx
      callOnDisplay(idx: idx, oview: optionalView(at: idx))
    }  
  }
  
  // Scroll to the cell at position index
  open func scrollto(_ idx: Int, animated: Bool = false) {
    if idx != _index {
      debug("scrolling to: \(idx)")
      _index = idx
      let ipath = IndexPath(item: idx, section: 0)
      scrollToItem(at: ipath, at: .centeredHorizontally, animated: animated)
    }
  }

  // MARK: - UICollectionViewDataSource
  
  open func numberOfSections(in collectionView: UICollectionView) -> Int {
    return 1
  }
  
  open func collectionView(_ collectionView: UICollectionView, 
    numberOfItemsInSection section: Int) -> Int {
    collectionViewInitialized = true
    return self.count
  }
  
  open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: 
      PageCollectionView.reuseIdent, for: indexPath) as? PageCell {
      let itemIndex = indexPath.item
      cell.update(pcv: self, idx: itemIndex)
      initialize(itemIndex)
      return cell
    }
    return PageCell()
  }
  
  // MARK: - UICollectionViewDelegateFlowLayout
  
  public func collectionView(_ collectionView: UICollectionView, 
    layout collectionViewLayout: UICollectionViewLayout,
    sizeForItemAt indexPath: IndexPath) -> CGSize {
    let size = UIDevice.current.orientation.isLandscape
      ? CGSize(width: pwidth, height: bounds.size.height - 180)
      : CGSize(width: pwidth, height: bounds.size.height)
    return size
  }
  
  // MARK: - UIScrollViewDelegate
  
  // Return index at a given scroll offset
  private func offset2index(_ offset: CGFloat) -> Int {
    let centerX = offset + cwidth/2
    let i = (centerX - inset) / cellWidth
    var idx = Int(round(i))
    if i - CGFloat(idx) > 0 { idx += 1 }
    return max(idx - 1, 0)
  }
  
  // Return scroll offset of given index
  private func index2offset(_ idx: Int) -> CGFloat {
    let offset = cellWidth * CGFloat(idx)
    return offset
  }
  
  // While scrolling update page index
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    let pageIndex = offset2index(contentOffset.x)
    if pageIndex != _index { updateDisplaying(pageIndex) }  
  }
  
  // When dragging stops, position collection view to a complete page  
  public func scrollViewWillEndDragging(_ scrollView: UIScrollView, 
                                        withVelocity velocity: CGPoint, 
                                        targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    if !isPagingEnabled {
      let pointee = targetContentOffset.pointee.x
      let idx = offset2index(pointee)
      targetContentOffset.pointee.x = index2offset(idx)
    }
  }

} // PageCollectionView
