# 🚀 Micro-Optimizations Applied - Performance Testing Guide

## Date: November 29, 2025
## Branch: 130-micro-optimizations

---

## 📊 Analysis from Flutter DevTools Profiling

### Issues Identified from Profiling Data:

1. **Frame Drops (Jank)** - Red spikes showing frames taking >16ms (missing 60 FPS target at ~83 FPS average)
2. **UI Thread Bottlenecks** - Peaks of ~18ms during list scrolling
3. **Excessive Widget Rebuilds** - Multiple rebuilds during data fetching
4. **Memory Pressure** - Frequent GC events (blue dots in memory chart)
5. **Raster Thread Load** - Heavy painting operations during scroll

---

## ✅ Micro-Optimizations Implemented

### 1. **Prescriptions List Widget** (`lib/ui/prescriptions/prescriptions_list_widget.dart`)

#### Optimization #1: ListView Performance Parameters
**Location**: Line ~330
```dart
ListView.builder(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  itemCount: filteredList.length,
  // 🚀 NEW: Cache extent for smoother scrolling
  cacheExtent: 500, // Cache 500px beyond viewport
  // 🚀 NEW: Repaint boundaries per item
  addRepaintBoundaries: true,
  // 🚀 NEW: Disable automatic keep-alives (we handle state at card level)
  addAutomaticKeepAlives: false,
  itemBuilder: (context, index) { ... }
)
```

**Expected Impact**:
- ✅ Reduce jank during fast scrolling by pre-rendering 500px ahead
- ✅ Isolate repaints to individual cards (no full list repaints)
- ✅ Lower memory usage by not keeping all items alive

#### Optimization #2: RepaintBoundary Isolation
**Location**: Line ~340
```dart
itemBuilder: (context, index) {
  final prescripcion = filteredList[index];
  // 🚀 NEW: RepaintBoundary isolates each card
  return RepaintBoundary(
    key: ValueKey('prescription_${prescripcion.id}'),
    child: _buildPrescripcionCard(prescripcion),
  );
}
```

**Expected Impact**:
- ✅ Each prescription card repaints independently
- ✅ Scrolling one card doesn't trigger repaints on others
- ✅ Reduce raster thread bottlenecks by ~30-40%

#### Optimization #3: Const Optimization
**Location**: Line ~375
```dart
Widget _buildPrescripcionCard(Prescripcion prescripcion) {
  final isActive = prescripcion.activa;
  final theme = Theme.of(context);
  
  // 🚀 NEW: Use const where possible
  const cardMargin = EdgeInsets.only(bottom: 12);
  const cardPadding = EdgeInsets.all(16);
  
  return Card(
    margin: cardMargin, // Reuses same instance
    ...
    child: Padding(
      padding: cardPadding, // Reuses same instance
      ...
    )
  );
}
```

**Expected Impact**:
- ✅ Reduce memory allocations during scrolling
- ✅ Flutter reuses const objects instead of creating new ones
- ✅ Minor but measurable GC pressure reduction

---

### 2. **Orders View** (`lib/ui/orders/orders_view.dart`)

#### Optimization #1: ListView Performance Parameters
**Location**: Line ~351
```dart
ListView.builder(
  padding: const EdgeInsets.all(16),
  itemCount: _orders.length,
  // 🚀 NEW: Enhanced scrolling performance
  physics: const AlwaysScrollableScrollPhysics(),
  cacheExtent: 400, // Cache 400px beyond viewport
  addRepaintBoundaries: true, // Auto repaint boundaries
  addAutomaticKeepAlives: false, // Don't need keep-alive for simple cards
  itemBuilder: (context, index) { ... }
)
```

**Expected Impact**:
- ✅ Smoother scrolling with 400px lookahead
- ✅ Reduced jank when scrolling through order history
- ✅ Better frame times (target: <11ms per frame)

#### Optimization #2: RepaintBoundary Isolation
**Location**: Line ~360
```dart
itemBuilder: (context, index) {
  final order = _orders[index];
  final pharmacy = _pharmacyCache[order.puntoFisicoId];
  
  // 🚀 NEW: RepaintBoundary isolates each order card
  return RepaintBoundary(
    key: ValueKey('order_${order.id}'),
    child: _buildOrderCard(order, pharmacy, theme, isDark),
  );
}
```

**Expected Impact**:
- ✅ Isolated repaints per order card
- ✅ Reduce UI thread spikes during scroll
- ✅ Maintain consistent 60 FPS

#### Optimization #3: Const Optimization
**Location**: Line ~375
```dart
Widget _buildOrderCard(Pedido order, PuntoFisico? pharmacy, ...) {
  // 🚀 NEW: Use const for static values
  const cardMargin = EdgeInsets.only(bottom: 12);
  const cardBorderRadius = 12.0;
  
  return Card(
    margin: cardMargin,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cardBorderRadius),
      ...
    ),
    ...
  );
}
```

**Expected Impact**:
- ✅ Reduce EdgeInsets allocations during scroll
- ✅ Reuse BorderRadius objects
- ✅ Lower GC pressure

---

### 3. **Home Screen TabBarView** (`lib/ui/home/home_screen.dart`)

#### Optimization #1: ClampingScrollPhysics
**Location**: Line ~500
```dart
TabBarView(
  controller: _tabController,
  // 🚀 NEW: Reduce physics overhead
  physics: const ClampingScrollPhysics(),
  children: [ ... ]
)
```

**Expected Impact**:
- ✅ Lighter physics calculations during tab switches
- ✅ Reduce bouncing effects that cause extra frames
- ✅ Faster tab transitions

---

## 🎯 Testing Instructions

### **Test Scenario 1: Prescriptions List Scrolling**

#### Steps:
1. Open the app on physical device (profiling on emulator is not accurate)
2. Navigate to **"Prescripciones"** tab
3. Ensure you have **15-20+ prescriptions** loaded (create test data if needed)
4. Open **Flutter DevTools** → **Performance** tab
5. Click **"Record"** button
6. **Slowly scroll** through the entire list (top to bottom)
7. Then **quickly fling scroll** through the list (fast gesture)
8. Stop recording

#### What to Capture:
- **Screenshot 1**: Frame timeline showing the scroll sequence
- **Screenshot 2**: CPU flame chart during scroll
- **Screenshot 3**: Memory graph showing GC events

#### Expected Improvements:
- ✅ **Frame time**: Should stay **<11ms** (90 FPS) during smooth scroll
- ✅ **Jank reduction**: Fewer red bars (frames >16ms)
- ✅ **UI thread time**: Should stay **<8ms** consistently
- ✅ **GC events**: Fewer blue dots (less memory churn)
- ✅ **Average FPS**: Should be **>85 FPS** (was ~83 FPS before)

---

### **Test Scenario 2: Orders List Scrolling**

#### Steps:
1. Stay on the same physical device
2. Navigate to **"Pedidos"** tab
3. Ensure you have **10-15+ orders** loaded
4. Open **Flutter DevTools** → **Performance** tab
5. Click **"Record"** button
6. **Slowly scroll** through orders
7. Then **quickly fling scroll**
8. Stop recording

#### What to Capture:
- **Screenshot 4**: Frame timeline for orders scroll
- **Screenshot 5**: CPU flame chart during orders scroll
- **Screenshot 6**: Memory graph

#### Expected Improvements:
- ✅ **Frame time**: **<11ms** for 60+ FPS
- ✅ **Smoother scroll**: No stuttering on fast fling
- ✅ **Raster thread**: Should show lower spikes
- ✅ **RepaintBoundary isolation**: Individual cards in flame chart

---

### **Test Scenario 3: Tab Switching Performance**

#### Steps:
1. Navigate to **"Inicio"** tab
2. Open **Flutter DevTools** → **Performance** tab
3. Click **"Record"** button
4. Quickly switch between tabs: **Inicio → Prescripciones → Pedidos → Inicio**
5. Repeat 5 times rapidly
6. Stop recording

#### What to Capture:
- **Screenshot 7**: Frame timeline showing tab switches
- **Screenshot 8**: Timeline events showing tab transitions

#### Expected Improvements:
- ✅ **Tab switch time**: **<200ms** per transition
- ✅ **No jank**: All frames **<16ms** during transitions
- ✅ **ClampingScrollPhysics**: Smoother animations

---

### **Test Scenario 4: Memory Profiling**

#### Steps:
1. Open **Flutter DevTools** → **Memory** tab
2. Click **"Record"** button
3. Perform this sequence:
   - Open app → Load prescriptions → Scroll through all
   - Switch to orders → Scroll through all
   - Switch to home → Scroll down
   - Repeat 3 times
4. Stop recording
5. Take **Snapshot** (camera icon)

#### What to Capture:
- **Screenshot 9**: Memory timeline graph (RSS, allocated, GC events)
- **Screenshot 10**: Memory snapshot showing heap usage

#### Expected Improvements:
- ✅ **RSS Memory**: Should stay **<150MB** (was ~200MB+ before)
- ✅ **GC frequency**: **<5 events per minute** during active scrolling
- ✅ **Memory leaks**: No upward trend after 3 cycles
- ✅ **Const optimization**: Fewer EdgeInsets/Widget allocations in snapshot

---

### **Test Scenario 5: CPU Profiling (Flame Chart)**

#### Steps:
1. Open **Flutter DevTools** → **CPU Profiler** tab
2. Click **"Record"** button
3. Perform:
   - Fast scroll in prescriptions (5 seconds)
   - Fast scroll in orders (5 seconds)
4. Stop recording
5. Switch to **"Bottom Up"** view

#### What to Capture:
- **Screenshot 11**: CPU Flame Chart showing widget build calls
- **Screenshot 12**: Bottom Up view sorted by "Self Time"

#### Expected Improvements:
- ✅ **Build widget time**: Each card should be **<1ms**
- ✅ **RepaintBoundary**: Should appear as separate entries in flame chart
- ✅ **No excessive rebuilds**: `setState` calls should be minimal
- ✅ **Isolate boundaries**: Clear separation between list items

---

## 📈 Performance Metrics to Compare

### Before Optimizations (from your screenshots):
| Metric | Before | Target After | 
|--------|--------|--------------|
| Average FPS | ~83 FPS | **>90 FPS** |
| Frame Time (avg) | ~12ms | **<11ms** |
| Jank (>16ms frames) | ~10-15% | **<5%** |
| UI Thread Peak | ~18ms | **<12ms** |
| Raster Thread Peak | ~15ms | **<10ms** |
| GC Events/min | ~8-10 | **<5** |
| Memory (RSS) | ~200MB+ | **<150MB** |

---

## 🔧 How to Profile (Step-by-Step)

### 1. Run App in Profile Mode:
```bash
flutter run --profile
```

### 2. Open DevTools:
- Copy the URL from terminal (looks like: `http://127.0.0.1:9100/?uri=...`)
- Open in Chrome browser
- Or run: `flutter pub global run devtools`

### 3. Connect Device:
- Ensure USB debugging is ON
- Device shows in DevTools device selector

### 4. Performance Tab:
- Click **"Performance"** tab
- Click **"Record"** (red circle)
- Perform user actions
- Click **"Stop"** (red square)
- Analyze frame chart and flame graph

### 5. Memory Tab:
- Click **"Memory"** tab
- Click **"Record"** button
- Perform actions
- Click **"Snapshot"** to capture heap
- Analyze allocated objects

---

## 🎨 What to Look For in New Screenshots

### Frame Timeline:
- ✅ **Green bars**: Good frames (<11ms)
- ⚠️ **Yellow bars**: Acceptable frames (11-16ms)
- ❌ **Red bars**: Jank frames (>16ms) - should be <5%

### Flame Chart:
- ✅ **Shorter flame heights**: Less time per method
- ✅ **RepaintBoundary sections**: Clear widget isolation
- ✅ **No deep call stacks**: Efficient widget trees

### Memory Graph:
- ✅ **Flat line**: Stable memory usage
- ✅ **Small GC spikes**: Quick garbage collection
- ❌ **Upward slope**: Memory leak (should not happen)

### Timeline Events:
- ✅ **Frame intervals**: Consistent spacing
- ✅ **Build times**: <2ms per widget
- ✅ **Paint times**: <5ms per frame

---

## 📸 Screenshot Naming Convention

Please name your new screenshots like this:

```
Before optimizations:
- 01_before_prescriptions_frame_timeline.png
- 02_before_prescriptions_flame_chart.png
- 03_before_orders_frame_timeline.png
- 04_before_memory_graph.png

After optimizations:
- 01_after_prescriptions_frame_timeline.png
- 02_after_prescriptions_flame_chart.png
- 03_after_orders_frame_timeline.png
- 04_after_memory_graph.png
- 05_after_tab_switch_timeline.png
- 06_after_memory_snapshot.png
- 07_after_cpu_flame_chart.png
```

---

## 🚀 Additional Optimizations to Consider (If Needed)

If tests show further issues, we can apply:

### Phase 2 Optimizations:
1. **Image Caching**: Use `CachedNetworkImage` for prescription/order images
2. **Lazy Loading**: Load only visible items with pagination
3. **Compute Isolates**: Move JSON parsing to background thread
4. **Shader Compilation**: Add warmup frames to prevent first-frame jank
5. **Custom Painters**: Replace complex widgets with CustomPaint

---

## 📝 Notes

- Always profile on **physical device** (not emulator)
- Run in **profile mode** (not debug mode)
- Test with **real data** (15+ items in lists)
- Clear app data before tests for consistency
- Close other apps to reduce interference

---

## ✅ Acceptance Criteria

Optimizations are successful if:

1. ✅ Average FPS increases to **>90 FPS**
2. ✅ Jank frames reduced to **<5%**
3. ✅ No frame time **>16ms** during normal scroll
4. ✅ GC events reduced to **<5 per minute**
5. ✅ Memory usage stays **<150MB**
6. ✅ Tab switches complete in **<200ms**

---

**Ready for testing! 🎯**

Generate the new profiling screenshots following the test scenarios above and compare them to your original baseline screenshots.
