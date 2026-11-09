document.addEventListener("DOMContentLoaded", () => {
  const bar = document.getElementById("historyBar");
  const timer = document.getElementById("bigTimer");
  const label = document.getElementById("phaseLabel");
  const fill = document.getElementById("progressFill");
  const pred = document.getElementById("nextPred");
  const predBox = pred ? pred.parentElement : null;
  const plane = document.getElementById("plane2");
  const canvas = document.getElementById("flightCanvas");
  const ctx = canvas ? canvas.getContext("2d") : null;

  let history = ["1.61x","1.54x","1.45x","4.29x","3.33x"];
  function renderHistory(){ if(!bar) return; bar.innerHTML = history.map(h=>{ const v=parseFloat(h); const cls = v>=10 ? "high" : v<1.5 ? "crash" : ""; return `<span class="${cls}">${h}</span>`; }).join(""); }
  renderHistory();
  function resize(){ if(!canvas) return; canvas.width = canvas.offsetWidth; canvas.height = canvas.offsetHeight; }
  resize(); window.addEventListener("resize", resize);

  let points = [];
  function drawCurve(){
    if(!ctx || !canvas) return;
    ctx.clearRect(0,0,canvas.width,canvas.height);
    if(points.length < 2) return;
    // Fill red area under curve - like photo
    ctx.beginPath();
    ctx.moveTo(points[0].x, canvas.height);
    ctx.lineTo(points[0].x, points[0].y);
    for(let i=1;i<points.length;i++){ ctx.lineTo(points[i].x, points[i].y); }
    ctx.lineTo(points[points.length-1].x, canvas.height);
    ctx.closePath();
    let grad = ctx.createLinearGradient(0,0,0,canvas.height);
    grad.addColorStop(0, "rgba(255,20,20,0.75)");
    grad.addColorStop(1, "rgba(180,0,0,0.35)");
    ctx.fillStyle = grad;
    ctx.fill();
    // Top bright red line
    ctx.beginPath();
    ctx.moveTo(points[0].x, points[0].y);
    for(let i=1;i<points.length;i++){ ctx.lineTo(points[i].x, points[i].y); }
    ctx.strokeStyle = "#ff2a2a";
    ctx.lineWidth = 4;
    ctx.shadowColor = "#ff0000";
    ctx.shadowBlur = 12;
    ctx.stroke();
    ctx.shadowBlur = 0;
  }

  let crashPoint = 2.00, state = "waiting", waitTime = 5.0, current = 1.00;
  function pickNext(){ const r=Math.random(); if(r<0.6) crashPoint=1.20+Math.random()*2.80; else if(r<0.9) crashPoint=4+Math.random()*4; else crashPoint=8+Math.random()*8; crashPoint=Math.round(crashPoint*100)/100; if(pred) pred.textContent=crashPoint.toFixed(2)+"x"; }
  if(pred) pred.textContent="2.00x";

  setInterval(()=>{
    if(state==="waiting"){
      waitTime-=0.1;
      if(label){ label.textContent="STARTING IN"; label.classList.remove("flew"); }
      if(timer){ timer.textContent=Math.max(0,waitTime).toFixed(1)+"s"; timer.classList.remove("flew"); }
      if(fill) fill.style.width=((5-waitTime)/5*100)+"%";
      if(plane){ plane.style.left="0px"; plane.style.bottom="0px"; plane.classList.remove("crashed"); }
      points=[{x:0, y:canvas.offsetHeight-2}]; drawCurve();
      if(waitTime<=0){ state="flying"; current=1.00; if(label) label.textContent="FLYING..."; }
    } else if(state==="flying"){
      current += 0.02 + (current*0.005);
      if(timer) timer.textContent=current.toFixed(2)+"x";
      if(fill) fill.style.width=Math.min(100,(current/crashPoint*100))+"%";
      if(plane && canvas){
        const p = Math.min(1, current / Math.max(crashPoint, 2));
        const x = 5 + (p * (canvas.offsetWidth - 120));
        const y = canvas.offsetHeight - 5 - (Math.pow(p, 1.9) * (canvas.offsetHeight - 70));
        plane.style.left = x+"px";
        plane.style.bottom = (canvas.offsetHeight - y - 30)+"px";
        plane.style.transform = "rotate("+(p*10)+"deg)";
        points.push({x: x+10, y: y+15});
        if(points.length > 120) points.shift();
        drawCurve();
      }
      if(current>=crashPoint){
        current=crashPoint;
        if(timer){ timer.textContent=current.toFixed(2)+"x"; timer.classList.add("flew"); }
        if(label){ label.textContent="FLEW AWAY!"; label.classList.add("flew"); }
        state="crashed";
        if(plane) plane.classList.add("crashed");
        history.unshift(current.toFixed(2)+"x"); renderHistory();
        setTimeout(()=>{ state="waiting"; waitTime=5.0; pickNext(); }, 3500);
      }
    }
  },100);
});



