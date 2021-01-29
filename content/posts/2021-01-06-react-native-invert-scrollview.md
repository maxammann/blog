---
layout: post
title: "React Native: Inverting a ScrollView"
date: 2021-01-06
slug: react-native-invert-scrollview
description: "Blog post about inverting or reversing a ScrollView on React-Native"

keywords: [ react-native, react ]
---

Sometimes you want to have a `ScrollView` which scrolls from right to left or from bottom. This can be handy when you use calendar views which often to from present to past.

The React Native documentation gives a good hint how to achieve this in the [FlatList](https://reactnative.dev/docs/0.62/flatlist#inverted) documentation. They mention "scale transforms of -1". What does this mean?

Actually the idea is very simple. First you flip the `ScrollView`. Then you also flip the content of the `ScrollView`. That way the `ScrollView` is flipped and goes now in the opposite direction. The content is flipped twice and therefore looks like it is not flipped at all.

Here is how to achieve this using a `ScrollView` instead of a `FlatList`. For a horizonal `ScrollView`:


```jsx
<ScrollView
   style={{ transform: [{ scaleX: -1 }] }}
   horizontal={true}
>
   <View
      style={{ transform: [{ scaleX: -1 }] }}
   >
   ...
   </View>
</ScrollView>
```


For a vertical `ScrollView`:

```jsx
<ScrollView
   style={{ transform: [{ scaleY: -1 }] }}
   horizontal={false}
>
   <View
      style={{ transform: [{ scaleY: -1 }] }}
   >
   ...
   </View>
</ScrollView>
```
