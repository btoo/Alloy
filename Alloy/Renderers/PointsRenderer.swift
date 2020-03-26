//
//  PointsRenderer.swift
//  Alloy
//
//  Created by Eugene Bokhan on 26/04/2019.
//

import Metal

final public class PointsRenderer {

    // MARK: - Properties

    /// Point positions described in a normalized coodrinate system.
    public var pointsPositions: [SIMD2<Float>] {
        set {
            self.pointCount = newValue.count
            self.pointsPositionsBuffer = try? self.vertexFunction
                                                  .device
                                                  .buffer(with: newValue,
                                                          options: .storageModeShared)
        }
        get {
            if let pointsPositionsBuffer = self.pointsPositionsBuffer,
               let pointsPositions = pointsPositionsBuffer.array(of: SIMD2<Float>.self,
                                                                 count: self.pointCount) {
                return pointsPositions
            } else {
                return []
            }
        }
    }
    /// Point color. Red is default.
    public var color: SIMD4<Float> = .init(1, 0, 0, 1)
    /// Point size in pixels. 40 is default.
    public var pointSize: Float = 40

    private var pointsPositionsBuffer: MTLBuffer?
    private var pointCount: Int = 0

    private let vertexFunction: MTLFunction
    private let fragmentFunction: MTLFunction
    private var renderPipelineStates: [MTLPixelFormat: MTLRenderPipelineState] = [:]

    // MARK: - Life Cycle

    /// Creates a new instance of PointsRenderer.
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

    /// Creates a new instance of PointsRenderer.
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

    // MARK: - Rendering

    /// Render points in a target texture.
    ///
    /// - Parameters:
    ///   - renderPassDescriptor: Render pass descriptor to be used.
    ///   - commandBuffer: Command buffer to put the rendering work items into.
    public func render(renderPassDescriptor: MTLRenderPassDescriptor,
                       commandBuffer: MTLCommandBuffer) throws {
        guard let renderTarget = renderPassDescriptor.colorAttachments[0].texture,
            self.vertexFunction
                .device
                .isPixelFormatRenderingCompatible(pixelFormat: renderTarget.pixelFormat)
        else { return }
        commandBuffer.render(descriptor: renderPassDescriptor, { renderEncoder in
            self.render(pixelFormat: renderTarget.pixelFormat,
                        renderEncoder: renderEncoder)
        })
    }

    /// Render points in a target texture.
    ///
    /// - Parameter renderEncoder: Container to put the rendering work into.
    public func render(pixelFormat: MTLPixelFormat,
                       renderEncoder: MTLRenderCommandEncoder) {
        guard self.pointCount != 0,
              let renderPipelineState = self.renderPipelineState(for: pixelFormat)
        else { return }
        // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool.
        renderEncoder.pushDebugGroup("Draw Points Geometry")
        // Set render command encoder state.
        renderEncoder.setRenderPipelineState(renderPipelineState)
        // Set any buffers fed into our render pipeline.
        renderEncoder.setVertexBuffer(self.pointsPositionsBuffer,
                                      offset: 0,
                                      index: 0)
        renderEncoder.set(vertexValue: self.pointSize,
                          at: 1)
        renderEncoder.set(fragmentValue: self.color,
                          at: 0)
        // Draw.
        renderEncoder.drawPrimitives(type: .point,
                                     vertexStart: 0,
                                     vertexCount: 1,
                                     instanceCount: self.pointCount)
        renderEncoder.popDebugGroup()
    }

    private static let vertexFunctionName = "pointVertex"
    private static let fragmentFunctionName = "pointFragment"
}
