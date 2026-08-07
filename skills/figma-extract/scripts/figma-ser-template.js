const page = await browser.getPage("F20E784177CCD16FA16E59E8EBD8ED07");
const out = await page.evaluate(async () => {
  const styleIds = new Set();
  function ser(n, depth) {
    if (n.visible === false) return null;
    const o = { id: n.id, name: n.name, type: n.type, x: Math.round(n.x), y: Math.round(n.y),
                w: Math.round(n.width), h: Math.round(n.height) };
    if (n.layoutMode && n.layoutMode !== "NONE") {
      o.layout = n.layoutMode; o.gap = n.itemSpacing;
      o.pad = [n.paddingTop, n.paddingRight, n.paddingBottom, n.paddingLeft];
      if (n.primaryAxisAlignItems) o.mainAlign = n.primaryAxisAlignItems;
      if (n.counterAxisAlignItems) o.crossAlign = n.counterAxisAlignItems;
    }
    if (n.maxWidth) o.maxW = n.maxWidth;
    if (n.layoutSizingHorizontal) o.sizeH = n.layoutSizingHorizontal;
    if (n.layoutSizingVertical) o.sizeV = n.layoutSizingVertical;
    if (typeof n.cornerRadius === "number" && n.cornerRadius) o.radius = n.cornerRadius;
    if (typeof n.opacity === "number" && n.opacity !== 1) o.opacity = Math.round(n.opacity * 100) / 100;
    if (n.type === "TEXT") {
      o.fontSize = n.fontSize;
      o.lineHeight = n.lineHeight && n.lineHeight.unit !== "AUTO" ? (n.lineHeight.value + n.lineHeight.unit) : "auto";
      try { o.font = n.fontName.family + " " + n.fontName.style; } catch (e) {}
      try { if (n.letterSpacing && n.letterSpacing.value) o.tracking = n.letterSpacing.value + n.letterSpacing.unit; } catch (e) {}
      o.chars = n.characters.slice(0, 40);
      if (n.textStyleId && typeof n.textStyleId === "string") { o.textStyleId = n.textStyleId; styleIds.add(n.textStyleId); }
    }
    try { const f = n.fills && n.fills[0];
      if (f && f.type === "SOLID" && f.visible !== false) {
        const c = f.color;
        o.fill = [c.r, c.g, c.b].map(v => Math.round(v * 255)).join(",");
        if (typeof f.opacity === "number" && f.opacity !== 1) o.fillOpacity = Math.round(f.opacity * 100) / 100;
      }
    } catch (e) {}
    if (n.fillStyleId && typeof n.fillStyleId === "string") { o.fillStyleId = n.fillStyleId; styleIds.add(n.fillStyleId); }
    try { const s = n.strokes && n.strokes[0];
      if (s && s.type === "SOLID" && s.visible !== false) {
        const c = s.color;
        o.stroke = [c.r, c.g, c.b].map(v => Math.round(v * 255)).join(",");
        o.strokeW = n.strokeWeight;
        if (n.strokeStyleId && typeof n.strokeStyleId === "string") { o.strokeStyleId = n.strokeStyleId; styleIds.add(n.strokeStyleId); }
      }
    } catch (e) {}
    if (n.type === "INSTANCE") {
      try { if (n.mainComponent) o.main = n.mainComponent.name; } catch (e) {}
      try { if (n.componentProperties) { const p = {}; for (const k in n.componentProperties) p[k.split("#")[0]] = n.componentProperties[k].value; o.props = p; } } catch (e) {}
    }
    if (depth > 0 && n.children) {
      o.children = n.children.map(c => ser(c, depth - 1)).filter(Boolean);
    }
    return o;
  }
  const frame = await figma.getNodeByIdAsync("NODEID");
  if (!frame) return { error: "not found: NODEID" };
  const tree = ser(frame, 14);
  const styles = {};
  for (const sid of styleIds) {
    try { const st = await figma.getStyleByIdAsync(sid); if (st) styles[sid] = st.name; } catch (e) {}
  }
  return { tree, styles };
});
console.log(JSON.stringify(out, null, 1));
