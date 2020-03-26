//
//  RectangleRenderer.swift
//  Alloy
//
//  Created by Eugene Bokhan on 23/04/2019.
//

import Metal

final public class RectangleRenderer {

    // MARK: - Properties

    /// Rectangle fill color. Red in default.
    public var color: SIMD4<Float> = .init(1, 0, 0, 1)
    /// Rectrangle described in a normalized coodrinate system.
    public var normalizedRect: CGRect = .zero

    private let vertexFunction: MTLFunction
    private let fragmentFunction: MTLFunction
    private var renderPipelineStates: [MTLPixelFormat: MTLRenderPipelineState] = [:]


    // MARK: - Life Cycle

    /// Creates a new instance of RectangleRenderer.
    ///
    /// - Parameters:
    ///   - context: Alloy's Metal context.
    ///   - pixelFormat: Color attachment's pixel format.
    /// - Throws: Library or function creation errors.
    public convenience init(context: MTLContext,
                            pixelFormat: MTLPixelFormat = .bgra8Unorm) throws {
        try self.init(library: context.library(for: Self.self),
                      pixelFormat: pixelFormat)
    }

    /// Creates a new instance of RectangleRenderer.
    ///
    /// - Parameters:
    ///   - library: Alloy's shader library.
    ///   - pixelFormat: Color attachment's pixel format.
    /// - Throws: Function creation error.
    public init(library: MTLLibrary,
                pixelFormat: MTLPixelFormat = .bgra8Unorm) throws {
        guard let vertexFunction = library.makeFunction(name: Self.vertexFunctionName),
              let fragmentFunction = library.makeFunction(name: Self.fragmentFunctionName)
        else { throw MetalError.MTLLibraryError.functionCreationFailed }
        self.vertexFunction = vertexFunction
        self.fragmentFunction = fragmentFunction
        try self.renderPipelineState(for: pixelFormat)
    }

    @discardableResult
    private func renderPipelineState(for pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState? {
        if self.renderPipelineStates[pixelFormat] == nil {
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction = self.vertexFunction
            renderPipelineDescriptor.fragmentFunction = self.fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
            renderPipelineDescriptor.colorAttachments[0].setup(blending: .alpha)

            self.renderPipelineStates[pixelFormat] = try? self.vertexFunction
                                                              .device
                                                              .makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        }
        return self.renderPipelineStates[pixelFormat]
    }

    // MARK: - Helpers

    private func constructRectangle() -> Rectangle {
        let topLeftPosition = SIMD2<Float>(Float(self.normalizedRect.minX),
                                           Float(self.normalizedRect.maxY))
        let bottomLeftPosition = SIMD2<Float>(Float(self.normalizedRect.minX),
                                              Float(self.normalizedRect.minY))
        let topRightPosition = SIMD2<Float>(Float(self.normalizedRect.maxX),
                                            Float(self.normalizedRect.maxY))
        let bottomRightPosition = SIMD2<Float>(Float(self.normalizedRect.maxX),
                                               Float(self.normalizedRect.minY))
        return Rectangle(topLeft: topLeftPosition,
                         bottomLeft: bottomLeftPosition,
                         topRight: topRightPosition,
                         bottomRight: bottomRightPosition)
    }

    // MARK: - Rendering

    /// Render a rectangle in a target texture.
    ///
    /// - Parameters:
    ///   - renderPassDescriptor: Render pass descriptor to be used.
    ///   - commandBuffer: Command buffer to put the rendering work items into.
    public func render(renderPassDescriptor: MTLRenderPassDescriptor,
                       commandBuffer: MTLCommandBuffer) throws {
        guard let pixelFormat = renderPassDescriptor.colorAttachments[0]
                                                    .texture?
                                                    .pixelFormat,
              self.vertexFunction
                  .device
                  .isPixelFormatRenderingCompatible(pixelFormat: pixelFormat)
        else { return }
        commandBuffer.render(descriptor: renderPassDescriptor, { renderEncoder in
            self.render(pixelFormat: pixelFormat,
                        renderEncoder: renderEncoder)
        })
    }

    /// Render a rectangle in a target texture.
    ///
    /// - Parameter renderEncoder: Container to put the rendering work into.
    public func render(pixelFormat: MTLPixelFormat,
                       renderEncoder: MTLRenderCommandEncoder) {
        guard self.normalizedRect != .zero,
              let renderPipelineState = self.renderPipelineState(for: pixelFormat)
        else { return }

        // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool.
        renderEncoder.pushDebugGroup("Draw Rectangle Geometry")
        // Set render command encoder state.
        renderEncoder.setRenderPipelineState(renderPipelineState)
        // Set any buffers fed into our render pipeline.
        let rectangle = self.constructRectangle()
        renderEncoder.set(vertexValue: rectangle,
                          at: 0)
        renderEncoder.set(fragmentValue: self.color,
                          at: 0)
        // Draw.
        renderEncoder.drawPrimitives(type: .triangleStrip,
                                     vertexStart: 0,
                                     vertexCount: 4)
        renderEncoder.popDebugGroup()
    }

    public static let vertexFunctionName = "rectVertex"
    public static let fragmentFunctionName = "primitivesFragment"
}
