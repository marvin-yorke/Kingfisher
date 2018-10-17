//
//  KingfisherManagerTests.swift
//  Kingfisher
//
//  Created by Wei Wang on 15/10/22.
//
//  Copyright (c) 2018 Wei Wang <onevcat@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import XCTest
@testable import Kingfisher

class KingfisherManagerTests: XCTestCase {
    
    var manager: KingfisherManager!
    
    override class func setUp() {
        super.setUp()
        LSNocilla.sharedInstance().start()
    }
    
    override class func tearDown() {
        LSNocilla.sharedInstance().stop()
        super.tearDown()
    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let uuid = UUID()
        let downloader = ImageDownloader(name: "test.manager.\(uuid.uuidString)")
        let cache = ImageCache(name: "test.cache.\(uuid.uuidString)")
        
        manager = KingfisherManager(downloader: downloader, cache: cache)
    }
    
    override func tearDown() {
        LSNocilla.sharedInstance().clearStubs()
        cleanDefaultCache()
        manager = nil
        super.tearDown()
    }
    
    func testRetrieveImage() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)

        let manager = self.manager!
        manager.retrieveImage(with: url, options: [.waitForCache]) { result in
            XCTAssertNotNil(result.value?.image)
            XCTAssertEqual(result.value!.cacheType, .none)

        manager.retrieveImage(with: url) { result in
            XCTAssertNotNil(result.value?.image)
            XCTAssertEqual(result.value!.cacheType, .memory)

        manager.cache.clearMemoryCache()
        manager.retrieveImage(with: url) { result in
            XCTAssertNotNil(result.value?.image)
            XCTAssertEqual(result.value!.cacheType, .disk)

        manager.cache.clearMemoryCache()
        manager.cache.clearDiskCache {
            manager.retrieveImage(with: url) { result in
                XCTAssertNotNil(result.value?.image)
                XCTAssertEqual(result.value!.cacheType, .none)
                exp.fulfill()
        }}}}}
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testRetrieveImageWithProcessor() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)
        let p = RoundCornerImageProcessor(cornerRadius: 20)
        let manager = self.manager!

        manager.retrieveImage(with: url, options: [.processor(p), .waitForCache]) { result in
            XCTAssertNotNil(result.value?.image)
            XCTAssertEqual(result.value!.cacheType, .none)
            
        manager.retrieveImage(with: url) { result in
            XCTAssertNotNil(result.value?.image)
            XCTAssertEqual(result.value!.cacheType, .none,
                           "Need a processor to get correct image. Cannot get from cache, need download again.")

        manager.retrieveImage(with: url, options: [.processor(p)]) { result in
            XCTAssertNotNil(result.value?.image)
            XCTAssertEqual(result.value!.cacheType, .memory)
                    
        self.manager.cache.clearMemoryCache()
        manager.retrieveImage(with: url, options: [.processor(p)]) { result in
            XCTAssertNotNil(result.value?.image)
            XCTAssertEqual(result.value!.cacheType, .disk)
                        
        self.manager.cache.clearMemoryCache()
        self.manager.cache.clearDiskCache {
            self.manager.retrieveImage(with: url, options: [.processor(p)]) { result in
                XCTAssertNotNil(result.value?.image)
                XCTAssertEqual(result.value!.cacheType, .none)

                exp.fulfill()
        }}}}}}
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testSuccessCompletionHandlerRunningOnMainQueueDefaultly() {
        let progressExpectation = expectation(description: "progressBlock running on main queue")
        let completionExpectation = expectation(description: "completionHandler running on main queue")

        let url = testURLs[0]
        stub(url, data: testImageData2, length: 123)
        
        manager.retrieveImage(with: url, options: nil, progressBlock: { _, _ in
            XCTAssertTrue(Thread.isMainThread)
            progressExpectation.fulfill()})
        {
            result in
            XCTAssertNil(result.error)
            XCTAssertTrue(Thread.isMainThread)
            completionExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testShouldNotDownloadImageIfCacheOnlyAndNotInCache() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)

        manager.retrieveImage(with: url, options: [.onlyFromCache]) { result in
            XCTAssertNil(result.value)
            XCTAssertNotNil(result.error)
            if case KingfisherError2.cacheError(reason: .imageNotExisting(let key)) = result.error! {
                XCTAssertEqual(key, url.cacheKey)
            } else {
                XCTFail()
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testErrorCompletionHandlerRunningOnMainQueueDefaultly() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2, statusCode: 404)

        manager.retrieveImage(with: url) { result in
            XCTAssertNotNil(result.error)
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue((result.error as! KingfisherError2).isInvalidResponseStatusCode(404))
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testSucessCompletionHandlerRunningOnCustomQueue() {
        let progressExpectation = expectation(description: "progressBlock running on custom queue")
        let completionExpectation = expectation(description: "completionHandler running on custom queue")

        let url = testURLs[0]
        stub(url, data: testImageData2, length: 123)

        let customQueue = DispatchQueue(label: "com.kingfisher.testQueue")
        manager.retrieveImage(with: url, options: [.callbackDispatchQueue(customQueue)], progressBlock: { _, _ in
            XCTAssertTrue(Thread.isMainThread)
            progressExpectation.fulfill()
        })
        {
            result in
            XCTAssertNil(result.error)
            if #available(iOS 10.0, tvOS 10.0, macOS 10.12, *) {
                dispatchPrecondition(condition: .onQueue(customQueue))
            }
            completionExpectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testDefaultOptionCouldApply() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)
        
        manager.defaultOptions = [.scaleFactor(2)]
        manager.retrieveImage(with: url, completionHandler: { result in
            #if !os(macOS)
            XCTAssertEqual(result.value!.image.scale, 2.0)
            #endif
            exp.fulfill()
        })
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testOriginalImageCouldBeStored() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)

        let manager = self.manager!
        let p = SimpleProcessor()
        let options: KingfisherOptionsInfo = [.processor(p), .cacheOriginalImage, .waitForCache]
        manager.downloadAndCacheImage(with: url, forKey: url.cacheKey, options: options) { result in
            
            var imageCached = manager.cache.imageCachedType(forKey: url.cacheKey, processorIdentifier: p.identifier)
            var originalCached = manager.cache.imageCachedType(forKey: url.cacheKey)

            XCTAssertEqual(imageCached, .memory)
            XCTAssertEqual(originalCached, .memory)

            delay(0.1) {
                manager.cache.clearMemoryCache()
                
                imageCached = manager.cache.imageCachedType(forKey: url.cacheKey, processorIdentifier: p.identifier)
                originalCached = manager.cache.imageCachedType(forKey: url.cacheKey)
                XCTAssertEqual(imageCached, .disk)
                XCTAssertEqual(originalCached, .disk)
                
                exp.fulfill()
            }
        }

        self.waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testOriginalImageNotBeStoredWithoutOptionSet() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)

        let p = SimpleProcessor()
        let options: KingfisherOptionsInfo = [.processor(p), .waitForCache]
        manager.downloadAndCacheImage(with: url, forKey: url.cacheKey, options: options) {
            result in
            var imageCached = self.manager.cache.imageCachedType(forKey: url.cacheKey, processorIdentifier: p.identifier)
            var originalCached = self.manager.cache.imageCachedType(forKey: url.cacheKey)
            
            XCTAssertEqual(imageCached, .memory)
            XCTAssertEqual(originalCached, .none)
            
            self.manager.cache.clearMemoryCache()
            
            imageCached = self.manager.cache.imageCachedType(forKey: url.cacheKey, processorIdentifier: p.identifier)
            originalCached = self.manager.cache.imageCachedType(forKey: url.cacheKey)
            XCTAssertEqual(imageCached, .disk)
            XCTAssertEqual(originalCached, .none)
            
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testCouldProcessOnOriginalImage() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        
        manager.cache.store(
            testImage,
            original: testImageData2,
            forKey: url.cacheKey,
            processorIdentifier: DefaultImageProcessor.default.identifier,
            cacheSerializer: DefaultCacheSerializer.default,
            toDisk: true)
        {
            let p = SimpleProcessor()
            
            let cached = self.manager.cache.imageCachedType(forKey: url.cacheKey, processorIdentifier: p.identifier)
            XCTAssertFalse(cached.cached)
            
            // No downloading will happen
            self.manager.retrieveImage(with: url, options: [.processor(p), .waitForCache]) { result in
                XCTAssertNotNil(result.value?.image)
                XCTAssertEqual(result.value!.cacheType, .none)
                XCTAssertTrue(p.processed)
                
                // The processed image should be cached
                let cached = self.manager.cache.imageCachedType(forKey: url.cacheKey, processorIdentifier: p.identifier)
                XCTAssertTrue(cached.cached)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testCacheOriginalImageWithOriginalCache() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        
        let originalCache = ImageCache(name: "test-originalCache")
        
        // Clear original cache first.
        originalCache.clearMemoryCache()
        originalCache.clearDiskCache {
            
            XCTAssertEqual(originalCache.imageCachedType(forKey: url.cacheKey), .none)
            
            stub(url, data: testImageData2)
            
            let p = RoundCornerImageProcessor(cornerRadius: 20)
            self.manager.retrieveImage(with: url, options: [.processor(p), .cacheOriginalImage, .originalCache(originalCache), .waitForCache]) {
                result in
                let originalCached = originalCache.imageCachedType(forKey: url.cacheKey)
                XCTAssertEqual(originalCached, .memory)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testCouldProcessOnOriginalImageWithOriginalCache() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        
        let originalCache = ImageCache(name: "test-originalCache")
        
        // Clear original cache first.
        originalCache.clearMemoryCache()
        originalCache.clearDiskCache {
            originalCache.store(
                testImage,
                original: testImageData2,
                forKey: url.cacheKey,
                processorIdentifier: DefaultImageProcessor.default.identifier,
                cacheSerializer: DefaultCacheSerializer.default,
                toDisk: true)
            {
                let p = SimpleProcessor()
                
                let cached = self.manager.cache.imageCachedType(forKey: url.cacheKey, processorIdentifier: p.identifier)
                XCTAssertFalse(cached.cached)
                
                // No downloading will happen
                self.manager.retrieveImage(with: url, options: [.processor(p), .originalCache(originalCache), .waitForCache]) {
                    result in
                    XCTAssertNotNil(result.value?.image)
                    XCTAssertEqual(result.value!.cacheType, .none)
                    XCTAssertTrue(p.processed)
                    
                    // The processed image should be cached
                    let cached = self.manager.cache.imageCachedType(forKey: url.cacheKey, processorIdentifier: p.identifier)
                    XCTAssertTrue(cached.cached)
                    exp.fulfill()
                }
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testWaitForCacheOnRetrieveImage() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)
        
        self.manager.retrieveImage(with: url, options: [.waitForCache]) { result in
            XCTAssertNotNil(result.value?.image)
            XCTAssertEqual(result.value!.cacheType, .none)
            
            self.manager.cache.clearMemoryCache()
            let cached = self.manager.cache.imageCachedType(forKey: url.cacheKey)
            XCTAssertEqual(cached, .disk)
            
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testNotWaitForCacheOnRetrieveImage() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)
        
        self.manager.retrieveImage(with: url, options: []) { result in
            XCTAssertNotNil(result.value?.image)
            XCTAssertEqual(result.value!.cacheType, .none)
            
            // We are not waiting for cache finishing here. So only sync memory cache is done.
            XCTAssertEqual(self.manager.cache.imageCachedType(forKey: url.cacheKey), .memory)
            
            // Once we clear the memory cache, it will be .none (Disk caching operation is not started yet.)
            self.manager.cache.clearMemoryCache()
            XCTAssertEqual(self.manager.cache.imageCachedType(forKey: url.cacheKey), .none)
            
            // After some time, the disk cache should be done.
            delay(0.1) {
                XCTAssertEqual(self.manager.cache.imageCachedType(forKey: url.cacheKey), .disk)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
    
    func testWaitForCacheOnRetrieveImageWithProcessor() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)
        let p = RoundCornerImageProcessor(cornerRadius: 20)
        self.manager.retrieveImage(with: url, options: [.processor(p), .waitForCache]) { result in
            XCTAssertNotNil(result.value?.image)
            XCTAssertEqual(result.value!.cacheType, .none)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testImageShouldOnlyFromMemoryCacheOrRefreshCanBeGotFromMemory() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)

        manager.retrieveImage(with: url, options: [.fromMemoryCacheOrRefresh, .waitForCache]) { result in
            // Can be downloaded and cached normally.
            XCTAssertNotNil(result.value?.image)
            XCTAssertEqual(result.value!.cacheType, .none)
            
            // Can still be got from memory even when disk cache cleared.
            self.manager.cache.clearDiskCache {
                self.manager.retrieveImage(with: url, options: [.fromMemoryCacheOrRefresh, .waitForCache]) { result in
                    XCTAssertNotNil(result.value?.image)
                    XCTAssertEqual(result.value!.cacheType, .memory)
                    
                    exp.fulfill()
                }
            }
        }
        
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testImageShouldOnlyFromMemoryCacheOrRefreshCanRefreshIfNotInMemory() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)

        manager.retrieveImage(with: url, options: [.fromMemoryCacheOrRefresh, .waitForCache]) { result in
            XCTAssertNotNil(result.value?.image)
            XCTAssertEqual(result.value!.cacheType, .none)
            XCTAssertEqual(self.manager.cache.imageCachedType(forKey: url.cacheKey), .memory)

            self.manager.cache.clearMemoryCache()
            XCTAssertEqual(self.manager.cache.imageCachedType(forKey: url.cacheKey), .disk)
            
            // Should skip disk cache and download again.
            self.manager.retrieveImage(with: url, options: [.fromMemoryCacheOrRefresh]) { result in
                XCTAssertNotNil(result.value?.image)
                XCTAssertEqual(result.value!.cacheType, .none)
                XCTAssertEqual(self.manager.cache.imageCachedType(forKey: url.cacheKey), .memory)

                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 5, handler: nil)
    }

    func testShouldDownloadAndCacheProcessedImage() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)

        let size = CGSize(width: 1, height: 1)
        let processor = ResizingImageProcessor(referenceSize: size)

        manager.retrieveImage(with: url, options: [.processor(processor), .waitForCache]) { result in
            // Can download and cache normally
            XCTAssertNotNil(result.value?.image)
            XCTAssertEqual(result.value!.image.size, size)
            XCTAssertEqual(result.value!.cacheType, .none)

            self.manager.cache.clearMemoryCache()
            let cached = self.manager.cache.imageCachedType(
                forKey: url.cacheKey, processorIdentifier: processor.identifier)
            XCTAssertEqual(cached, .disk)

            self.manager.retrieveImage(with: url, options: [.processor(processor)]) { result in
                XCTAssertNotNil(result.value?.image)
                XCTAssertEqual(result.value!.image.size, size)
                XCTAssertEqual(result.value!.cacheType, .disk)

                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

#if os(iOS) || os(tvOS) || os(watchOS)
    func testShouldApplyImageModifierWhenDownload() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)

        var modifierCalled = false
        let modifier = AnyImageModifier { image in
            modifierCalled = true
            return image.withRenderingMode(.alwaysTemplate)
        }
        manager.retrieveImage(with: url, options: [.imageModifier(modifier)]) { result in
            XCTAssertTrue(modifierCalled)
            XCTAssertEqual(result.value?.image.renderingMode, .alwaysTemplate)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testShouldApplyImageModifierWhenLoadFromMemoryCache() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)
        
        var modifierCalled = false
        let modifier = AnyImageModifier { image in
            modifierCalled = true
            return image.withRenderingMode(.alwaysTemplate)
        }

        manager.cache.store(testImage, forKey: url.cacheKey)
        manager.retrieveImage(with: url, options: [.imageModifier(modifier)]) { result in
            XCTAssertTrue(modifierCalled)
            XCTAssertEqual(result.value?.cacheType, .memory)
            XCTAssertEqual(result.value?.image.renderingMode, .alwaysTemplate)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testShouldApplyImageModifierWhenLoadFromDiskCache() {
        let exp = expectation(description: #function)
        let url = testURLs[0]
        stub(url, data: testImageData2)

        var modifierCalled = false
        let modifier = AnyImageModifier { image in
            modifierCalled = true
            return image.withRenderingMode(.alwaysTemplate)
        }

        manager.cache.store(testImage, forKey: url.cacheKey) {
            self.manager.cache.clearMemoryCache()
            self.manager.retrieveImage(with: url, options: [.imageModifier(modifier)]) { result in
                XCTAssertTrue(modifierCalled)
                XCTAssertEqual(result.value!.cacheType, .disk)
                XCTAssertEqual(result.value!.image.renderingMode, .alwaysTemplate)
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
    }
#endif
}

class SimpleProcessor: ImageProcessor {
    public let identifier = "id"
    var processed = false
    /// Initialize a `DefaultImageProcessor`
    public init() {}
    
    /// Process an input `ImageProcessItem` item to an image for this processor.
    ///
    /// - parameter item:    Input item which will be processed by `self`
    /// - parameter options: Options when processing the item.
    ///
    /// - returns: The processed image.
    ///
    /// - Note: See documentation of `ImageProcessor` protocol for more.
    public func process(item: ImageProcessItem, options: KingfisherOptionsInfo) -> Image? {
        processed = true
        switch item {
        case .image(let image):
            return image
        case .data(let data):
            return KingfisherClass<Image>.image(data: data, options: options.imageCreatingOptions)
        }
    }
}

