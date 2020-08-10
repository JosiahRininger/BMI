//
//  AdView.swift
//  BMI
//
//  Created by Josiah Rininger on 8/8/20.
//  Copyright © 2020 Josiah Rininger. All rights reserved.
//

import SwiftUI
import GoogleMobileAds

struct AdView: UIViewRepresentable {
    @State private var banner: GADBannerView = GADBannerView(adSize: kGADAdSizeBanner)
    
    func makeUIView(context: UIViewRepresentableContext<AdView>) -> GADBannerView {
        banner.adUnitID = Constants.Strings.adUnitID

        banner.load(GADRequest())
        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            return banner
        }
        
        banner.rootViewController = rootViewController
        
        let frame = { () -> CGRect in
            return banner.rootViewController!.view.frame.inset(by: banner.rootViewController!.view.safeAreaInsets)
        }()
        let viewWidth = frame.size.width

        banner.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(viewWidth)

        banner.load(GADRequest())
        return banner
    }
    
    func updateUIView(_ uiView: GADBannerView, context: UIViewRepresentableContext<AdView>) {
    }
}
