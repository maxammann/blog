---
layout: post
title: "Clipping Objects using Stencil Testing in WebGPU and wgpu"
date: 2022-01-04T13:30:22+01:00
slug: wgpu-stencil-testing
draft: false
wip: false

resources:
- src: "*.png"
- src: "*.jpg"

keywords: [ ]
categories: [ mapr ]
---

Stencil testing refers to a technique in computer graphics programming which allows conditional processing of fragments. Stencil testing is closely related to depth testing which is used to determine which fragment precedence based on its depth within the scene.
In fact both tests are handled through the very same interface in WebGPU. The tests are handled through the [Depth/Stencil State](https://www.w3.org/TR/webgpu/#depth-stencil-state).

In this post we are focusing on a specific implementation of the WebGPU specification called [wgpu](https://github.com/gfx-rs/wgpu). It is a safe and portable GPU abstraction in Rust which implements the WebGPU API. Generally, the technique described below will also work for other implementations of WebGPU like it will be available in JavaScript.

## What is Stencil Testing?

After the execution of the fragment shader, a so-called "Stencil Text" is performed. The outcome of the test determines whether the pixel corresponding to the fragment is drawn or not.

This test uses information from the current draw call, as well as contextual information which is encoded in a stencil buffer. The stencil buffer is a 2D texture of shape `(Screen Width, Screen Height)`. Each stencil value within the buffer usually has 8 bits. Initially the stencil buffer is initialized with zeros.

The Figure below shows the result of the fragment shader (Color buffer), a stencil buffer and the result after applying the stencil buffer.

{{< resourceFigure "learnopengl-stencil_buffer.png" "top-left" >}}[Stencil testing](https://learnopengl.com/Advanced-OpenGL/Stencil-testing) (Joey de Vries CC BY-NC 4.0){{< /resourceFigure >}}


From an abstract perspective the stencil test can be seen as the following function which is executed per screen pixel. While graphics programmers can not implement this directly, this function should serve as a mental model.

```rust
type StencilValue = u8;
fn stencil_test(x: u32, y: u32, 
                stencil_state: &StencilFaceState,
                stencil_buffer: &mut [[StencilValue;SCREEN_HEIGHT];SCREEN_WIDTH],  
                reference_value: StencilValue,
                write_mask: StencilValue, read_mask: StencilValue) -> bool;
```

The function returns for each pixel with screen coordinates `x` and `y` whether it should be drawn or not. The `stencil_state` holds the configuration for the stencil test.
There is also a `reference_value` which is supplied with each draw in WebGPU.
Note that the `stencil_buffer` is mutable, which means that the function `stencil_test` is allowed to update the stencil buffer during the test. **In fact executing a stencil test is the only way to update the stencil buffer.** `write_mask` and `read_mask` are special values which will be covered later when.

The configuration of a `wgpu::StencilFaceState` in WebGPU essentially defines the implementation of the `stencil_test` function. Let's see now how we can configure stencil testing in WebGPU.

## WebGPU Pipeline Configuration

In WebGPU rendering is configured though pipeline descriptor. The `wgpu::RenderPipelineDescriptor` holds the blueprint for creating a pipeline. Let's review some code which includes the gist of the configuration of a stencil buffer.

The majority of the values below are excluded as they are not important for stencil testing. I also excluded settings for depth testing as this is not the topic of this blog post. It is noteworthy though that depth testing interferes with stencil testing. WebGPU also combines the configuration of both via a single state.


```rust {hl_lines=["2-5",11,"16-21"]}
let stencil_state = wgpu::StencilFaceState {
    compare: wgpu::CompareFunction::Always,
    fail_op: wgpu::StencilOperation::Keep,
    depth_fail_op: wgpu::StencilOperation::Keep,
    pass_op: wgpu::StencilOperation::IncrementClamp,
};

wgpu::RenderPipelineDescriptor {
    ....
    depth_stencil: Some(wgpu::DepthStencilState {
        format: wgpu::TextureFormat::Depth24PlusStencil8,
        depth_write_enabled: ...,
        depth_compare: ...,
        bias: ...,
        stencil: wgpu::StencilState {
            front: stencil_state,
            back: stencil_state,
            // Applied to values being read from the buffer
            read_mask: 0xff,
            // Applied to values before being written to the buffer
            write_mask: 0xff,
        }
    })
}

```

* In line 11 a pixel format for the stencil testing is defined. Because depth and stencil testing have similar goals the context of both tests is stored in a single texture. In this case we define that every pixel uses 24 bits for the depth buffer and 8 bit for the stencil buffer.

* Lines 16-21 two `wgpu::StencilFaceState` for stencil testing: `front` and `back`. It is possible to define two different stencil states depending on which side of a triangle is rendered. For this example we choose the same for both sides.
  
  We also define `read_mask` and `write_mask` which will be used during the stencil test.

* Lines 2-5 define the logic behind the stencil test. In the next part I will show how these options determine the output of the stencil test by providing an imaginary implementation.

During the rendering loop you have the possibility to set a reference stencil value `reference_value` like shown here:

```rust
let mut pass: wgpu::RenderPass = ...;
let mut pipeline: &wgpu::RenderPipeline = ...;
let mut vertex_buffer: wgpu::BufferSlice = ...;
pass.set_pipeline(&pipeline);
pass.set_vertex_buffer(0, vertex_buffer);
pass.set_stencil_reference(some_reference_value);
// Draw something
pass.draw(0..3, 0..1);
```

We have now covered the WebGPU API which is responsible for stencil buffers. There are no other functions you need to know of! We need to get now an idea what the configuration does!

## Imaginary Implementation for Stencil Testing

The following imaginary implementation of the `stencil_test` function should serve you as a mental model. By reading this function carefully you should be able to understand what the configuration of the `wgpu::StencilState`  or call to `pass.set_stencil_reference(...)` does. If you understand the implementation below, then you also know what WebGPU will render given a specific stencil state.


```rust
/// Tests whether the fragment at `x` and `y` should be drawn or not. It also updates the stencil_buffer if required by the `stencil_state`.
fn stencil_test(x: u32, y: u32, 
                // This state is either the `front` or `back` state supplied by the `wgpu::StencilState` config.
                stencil_state: &StencilFaceState,
                stencil_buffer: &mut [[StencilValue;SCREEN_HEIGHT];SCREEN_WIDTH]
                // stencil value with value provided in most recent call to RenderPass::set_stencil_reference.
                reference_value: StencilValue,
                // These two masks come from the `wgpu::StencilState` config
                write_mask: StencilValue, read_mask: StencilValue) -> bool {
    // Read from the stencil buffer
    let current_value = stencil_buffer[x][y] & read_mask;

    // Does the current value pass the stencil test?
    let does_pass = match stencil_state.compare {
        Never =>  false,
        Always =>  true,
        Less => current_value < reference_value,
        Equal => current_value == reference_value,
        LessEqual => current_value <= reference_value,
        Greater => current_value > reference_value,
        NotEqual => current_value != reference_value,
        GreaterEqual => current_value >= reference_value,
    }

    if does_pass {
        update_stencil_buffer(stencil_state.pass_op, stencil_buffer);
        return true;
    } else {
        update_stencil_buffer(stencil_state.fail_op, stencil_buffer);
        return false;
    }
}

/// Updates the stencil buffer according to `reference_value`
fn update_stencil_buffer(x: u32, y: u32,
                         reference_value: StencilValue,
                         operation: &StencilOperation, 
                         stencil_buffer: &mut [[StencilValue;SCREEN_HEIGHT];SCREEN_WIDTH]) {
    match operation {
        Keep => { }
        /// Set stencil value to zero.
        Zero => { stencil_buffer[x][y] = 0; }
        /// Replace stencil value with value provided in most recent call to set_stencil_reference.
        Replace => { stencil_buffer[x][y] = reference_value; }
        /// Bitwise inverts stencil value.
        Invert => { stencil_buffer[x][y] = !stencil_buffer[x][y]; }
        /// Increments stencil value by one, clamping on overflow.
        IncrementClamp => { if (stencil_buffer[x][y] != 255) { stencil_buffer[x][y] = stencil_buffer[x][y] + 1; }  }
        /// Decrements stencil value by one, clamping on underflow.
        DecrementClamp => { if (stencil_buffer[x][y] != 0) { stencil_buffer[x][y] = stencil_buffer[x][y] - 1; } }
        /// Increments stencil value by one, wrapping on overflow.
        IncrementWrap => { stencil_buffer[x][y] = stencil_buffer[x][y] + 1; }
        /// Decrements stencil value by one, wrapping on underflow.
        DecrementWrap => { stencil_buffer[x][y] = stencil_buffer[x][y] - 1; }
    }
}
```

A minor simplification is that I excluded the `depth_fail_op` of `wgpu::StencilFaceState`. This operation is executed instead of `fail_op` if the depth test failed.

## Clipping Objects using Stencil Testing

One usage for stencil testing is clipping of geometries. Let's image for example we currently render a complex shape. We now notice that the complex shape is too big, and we want to clip it with another geometry.

This can be achieved by creating two separate pipelines in WebGPU. One pipeline draws a mask against which we want to clip the geometry. The other pipeline draws the actual complex shape.
We draw now a mask in the stencil buffer by using the following draw calls:

```rust
let mut pass: wgpu::RenderPass = ...;
let mut mask_pipeline: &wgpu::RenderPipeline = ...;
let mut vertex_buffer: wgpu::BufferSlice = ...;
pass.set_pipeline(&mask_pipeline);
pass.set_vertex_buffer(0, vertex_buffer);
// Draw the mask
pass.draw(0..3, 0..1);
```

The `mask_pipeline` has the following stencil state:
```rust
let stencil_state = wgpu::StencilFaceState {
    compare: wgpu::CompareFunction::Always,
    fail_op: wgpu::StencilOperation::Keep,
    depth_fail_op: wgpu::StencilOperation::Keep,
    pass_op: wgpu::StencilOperation::IncrementClamp,
};
```

Because the stencil buffer is initialized with zeroes, the draw above will increment the stencil values which are covered by the mask to 1. The are incremented because the pass operation `IncrementClamp` is used.

Now let's draw the complex shape:

```rust
let mut pass: wgpu::RenderPass = ...;
let mut pipeline: &wgpu::RenderPipeline = ...;
let mut vertex_buffer: wgpu::BufferSlice = ...;
pass.set_pipeline(&pipeline);
pass.set_vertex_buffer(0, vertex_buffer);
pass.set_stencil_reference(1);
// Draw the complex shape
pass.draw(0..1000, 0..1);
```

The `pipeline` has the following stencil state:
```rust
let stencil_state = wgpu::StencilFaceState {
    compare: wgpu::CompareFunction::Equal,
    fail_op: wgpu::StencilOperation::Keep,
    depth_fail_op: wgpu::StencilOperation::Keep,
    pass_op: wgpu::StencilOperation::Keep,
};
```

This state never changes the stencil buffer, but only draws pixels which have a 1 in the stencil buffer. The reason for this is that we set the stencil reference value to 1 with `pass.set_stencil_reference(1)`, and we went with the `Equal` compare function.

This technique can be used in vector map rendering, where quadratic tiles of geographic data are drawn. The tiles contain vector graphics which can extend beyond the boundaries of a tile. By using squares as a mask it is possible to clip the tiles. An example project which uses clipping is [mapr](https://github.com/maxammann/mapr/).

## Other Applications for Stencil Testing

Other usages for stencil testing can be discovered [here](https://learnopengl.com/Advanced-OpenGL/Stencil-testing). It can be used for example to outline objects.