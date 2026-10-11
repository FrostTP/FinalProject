'use strict';
// OSM expects a real Referer; send only the origin, never employee IDs or query strings.
if(typeof L!=='undefined' && L.drawLocal){
 L.drawLocal.draw.toolbar.buttons.polygon='วาดขอบเขตหลายเหลี่ยม';
 L.drawLocal.draw.toolbar.actions.title='ยกเลิกการวาด';
 L.drawLocal.draw.toolbar.actions.text='ยกเลิก';
 L.drawLocal.draw.toolbar.finish.title='ปิดขอบเขตที่วาด';
 L.drawLocal.draw.toolbar.finish.text='วาดเสร็จ';
 L.drawLocal.draw.toolbar.undo.title='ลบจุดล่าสุด';
 L.drawLocal.draw.toolbar.undo.text='ลบจุดล่าสุด';
 L.drawLocal.draw.handlers.polygon.tooltip.start='คลิกบนแผนที่เพื่อเริ่มวาดขอบเขต';
 L.drawLocal.draw.handlers.polygon.tooltip.cont='คลิกเพิ่มจุดตามขอบพื้นที่';
 L.drawLocal.draw.handlers.polygon.tooltip.end='คลิกจุดแรกเพื่อปิดขอบเขต';
 L.drawLocal.edit.toolbar.buttons.edit='ปรับจุดขอบเขต';
 L.drawLocal.edit.toolbar.buttons.editDisabled='วาดขอบเขตก่อนแก้ไข';
 L.drawLocal.edit.toolbar.buttons.remove='ลบขอบเขตเพื่อวาดใหม่';
 L.drawLocal.edit.toolbar.buttons.removeDisabled='ยังไม่มีขอบเขตให้ลบ';
 L.drawLocal.edit.toolbar.actions.save.title='ยืนยันจุดที่ปรับ';
 L.drawLocal.edit.toolbar.actions.save.text='ยืนยัน';
 L.drawLocal.edit.toolbar.actions.cancel.title='ยกเลิกการปรับ';
 L.drawLocal.edit.toolbar.actions.cancel.text='ยกเลิก';
 L.drawLocal.edit.handlers.edit.tooltip.text='ลากจุดมุมเพื่อปรับขอบเขตหลายเหลี่ยม';
 L.drawLocal.edit.handlers.edit.tooltip.subtext='ลากจุดกลางเส้นเพื่อเพิ่มมุม แล้วกดยืนยัน';
 L.drawLocal.edit.handlers.remove.tooltip.text='คลิกขอบเขตที่ต้องการลบ';
}
// One component for polygon editing, assignment preview and attendance verification.
document.querySelectorAll('[data-map]').forEach(el => {
 if(typeof L==='undefined'){el.textContent='โหลดเครื่องมือแผนที่ไม่สำเร็จ กรุณาตรวจไฟล์ assets/vendor';return;}
 const map=L.map(el).setView([13.7563,100.5018],13);
 const tiles=L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,referrerPolicy:'origin',attribution:'&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'}).addTo(map);
 let mapNotice=null;
 tiles.on('tileerror',()=>{
  if(mapNotice)return;
  mapNotice=document.createElement('p');mapNotice.className='alert alert-warning mt-2';mapNotice.setAttribute('role','status');
  mapNotice.textContent='โหลดภาพแผนที่บางส่วนไม่ได้ กรุณาตรวจอินเทอร์เน็ตหรือส่วนขยายที่บล็อก Referer แล้วโหลดหน้าใหม่';
  el.insertAdjacentElement('afterend',mapNotice);
 });
 map.createPane('campus-boundary');map.getPane('campus-boundary').style.zIndex='380';
 map.createPane('department-boundaries');map.getPane('department-boundaries').style.zIndex='390';
 const shapes=new L.FeatureGroup().addTo(map);let point=null;
 const parse=value=>{try{return JSON.parse(value||'[]');}catch{return [];}};
 const contextBounds=L.latLngBounds([]);const overlayGroups=new Map();
 const colors=['#2f66f6','#12b981','#ef4444','#8b5cf6','#ff922b','#0891b2','#db2777'];
 const colorFor=id=>{let hash=0;for(const c of id)hash=((hash<<5)-hash+c.charCodeAt(0))|0;return colors[(hash>>>0)%colors.length];};
 const labelHtml=(text,color)=>{const label=document.createElement('span');const swatch=document.createElement('span');swatch.style.cssText=`display:inline-block;width:12px;height:12px;background:${color};margin-right:6px;border-radius:2px`;label.append(swatch,document.createTextNode(text));return label.outerHTML;};
 const overlays=parse(el.dataset.overlays);
 if(Array.isArray(overlays))for(const area of overlays){
  if(!Array.isArray(area.polygon)||area.polygon.length<3)continue;
  const campus=area.kind==='campus';const groupKey=campus?'campus':area.department_id;
  const color=campus?'#202938':colorFor(area.department_id);
  if(!overlayGroups.has(groupKey))overlayGroups.set(groupKey,{layer:L.featureGroup().addTo(map),label:labelHtml(campus?'ขอบเขตมหาวิทยาลัย':area.department_name,color)});
  const boundary=L.polygon(area.polygon.map(p=>[p.lat,p.lng]),{pane:campus?'campus-boundary':'department-boundaries',color,weight:campus?4:2,fillOpacity:campus?.04:.18});
  const popup=document.createElement('div');popup.textContent=`${area.area_name} · ${campus?'ขอบเขตมหาวิทยาลัย':area.department_name}`;
  boundary.bindPopup(popup).addTo(overlayGroups.get(groupKey).layer);contextBounds.extend(boundary.getBounds());
 }
 if(overlayGroups.size){const controls={};for(const group of overlayGroups.values())controls[group.label]=group.layer;L.control.layers(null,controls,{collapsed:false,position:'topright'}).addTo(map);}
 const fit=()=>{const bounds=shapes.getBounds();if(point)bounds.extend(point.getLatLng());if(!bounds.isValid()&&contextBounds.isValid())bounds.extend(contextBounds);if(bounds.isValid())map.fitBounds(bounds,{padding:[30,30],maxZoom:17});};
 const render=coords=>{shapes.clearLayers();if(Array.isArray(coords)&&coords.length>=3)shapes.addLayer(L.polygon(coords.map(p=>[p.lat,p.lng]),{color:'#2f66f6',weight:3,fillOpacity:.15}));fit();};
 render(parse(el.dataset.polygon));
 if(el.dataset.point){const p=parse(el.dataset.point);if(Number.isFinite(+p.lat)&&Number.isFinite(+p.lng)){point=L.circleMarker([+p.lat,+p.lng],{radius:9,color:'#fff',weight:3,fillColor:'#ef4444',fillOpacity:1}).addTo(map).bindPopup('ตำแหน่งที่ลงเวลา');fit();}}
 if(el.dataset.mode==='edit') {
  const hidden=document.getElementById('polygon_coordinates');const status=document.getElementById('map-status');
  if(!L.Control.Draw){status.textContent='โหลดเครื่องมือวาดขอบเขตไม่สำเร็จ';return;}
  map.addControl(new L.Control.Draw({draw:{polygon:{allowIntersection:false,showArea:true,shapeOptions:{color:'#2f66f6'}},polyline:false,rectangle:false,circle:false,marker:false,circlemarker:false},edit:{featureGroup:shapes}}));
  const sync=()=>{const layer=shapes.getLayers()[0];const coords=layer?layer.getLatLngs()[0].map(p=>({lat:p.lat,lng:p.lng})):[];hidden.value=JSON.stringify(coords);status.textContent=coords.length?`กำหนดขอบเขต ${coords.length} จุด · กดบันทึกพื้นที่เพื่อยืนยัน`:'กรุณาวาดขอบเขตใหม่ โดยมีพื้นที่มหาวิทยาลัยและแผนกอื่นเป็นชั้นอ้างอิง';};
  map.on(L.Draw.Event.CREATED,ev=>{shapes.clearLayers();shapes.addLayer(ev.layer);sync();});
  map.on(L.Draw.Event.EDITED,sync);map.on(L.Draw.Event.DELETED,sync);sync();
  document.querySelector('[data-fit]')?.addEventListener('click',fit);
  document.querySelector('[data-locate]')?.addEventListener('click',()=>{const parts=document.getElementById('locate-coordinates').value.split(',').map(s=>s.trim());const [lat,lng]=parts.map(Number);if(parts.length!==2||parts.some(s=>s==='')||!Number.isFinite(lat)||!Number.isFinite(lng)||Math.abs(lat)>90||Math.abs(lng)>180){status.textContent='ระบุละติจูด,ลองจิจูดที่ถูกต้อง';return;}map.setView([lat,lng],17);});
  document.getElementById('record-form')?.addEventListener('submit',ev=>{sync();if(parse(hidden.value).length<3){ev.preventDefault();status.textContent='กรุณาวาด Polygon อย่างน้อย 3 จุด';el.scrollIntoView({behavior:'smooth'});}});
 }
 if(el.dataset.mode==='preview'){const areas=parse(el.dataset.areas);const select=document.getElementById('area_id');const show=()=>render(parse(areas[select.value]));select.addEventListener('change',show);show();}
 new ResizeObserver(()=>map.invalidateSize()).observe(el);
});
