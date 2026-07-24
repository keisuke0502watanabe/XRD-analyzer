(function(){
  function naturalKey(str){
    return String(str).split(/(\d+)/).map((s,i)=>i%2===0?s.toLowerCase():parseInt(s,10));
  }

  function naturalCompareByName(a,b){
    const ka=naturalKey(a.name);
    const kb=naturalKey(b.name);
    for(let i=0;i<Math.max(ka.length,kb.length);i++){
      const ai=ka[i]??'';
      const bi=kb[i]??'';
      if(ai<bi)return -1;
      if(ai>bi)return 1;
    }
    return 0;
  }

  function naturalCompareText(a,b){
    const ka=naturalKey(a);
    const kb=naturalKey(b);
    for(let i=0;i<Math.max(ka.length,kb.length);i++){
      const ai=ka[i]??'';
      const bi=kb[i]??'';
      if(ai<bi)return -1;
      if(ai>bi)return 1;
    }
    return 0;
  }

  /**
   * Rigaku SmartLab .ras: *MEAS_SCAN_*_TIME "MM/DD/YY HH:mm:ss" (US-style date, 2-digit year).
   * Example: 12/01/25 17:23:55 → 2025-12-01 local (yy 00–69 → 20yy, else 19yy).
   */
  function parseDateTime(s){
    if(!s)return null;
    const m=String(s).trim().match(/^(\d{1,2})\/(\d{1,2})\/(\d{2,4})\s+(\d{1,2}):(\d{1,2}):(\d{1,2})/);
    if(!m)return null;
    const mo=parseInt(m[1],10),dd=parseInt(m[2],10),yyStr=m[3];
    const hh=parseInt(m[4],10),mi=parseInt(m[5],10),ss=parseInt(m[6],10);
    const yy=parseInt(yyStr,10);
    const year=yyStr.length===2&&!isNaN(yy)?(yy<=69?2000+yy:1900+yy):yy;
    if(!Number.isFinite(year)||!Number.isFinite(mo)||!Number.isFinite(dd)||mo<1||mo>12||dd<1||dd>31)return null;
    const d=new Date(year,mo-1,dd,hh,mi,ss);
    return isNaN(d.getTime())?null:d;
  }

  function parseRas(text,fname,color){
    const lines=text.split(/\r?\n/);
    let inData=false;
    const tth=[];
    const intensity=[];
    let tempStart=null;
    let tempEnd=null;
    let timeStart=null;
    let timeEnd=null;
    for(const line of lines){
      if(line.includes('*ATMOSPHERE_TEMP_START')){const v=parseFloat(line.match(/"([^"]+)"/)?.[1]);tempStart=Number.isFinite(v)?v:null;}
      if(line.includes('*ATMOSPHERE_TEMP_END')){const v=parseFloat(line.match(/"([^"]+)"/)?.[1]);tempEnd=Number.isFinite(v)?v:null;}
      if(line.includes('*MEAS_SCAN_START_TIME'))timeStart=parseDateTime(line.match(/"([^"]+)"/)?.[1]);
      if(line.includes('*MEAS_SCAN_END_TIME'))timeEnd=parseDateTime(line.match(/"([^"]+)"/)?.[1]);
      if(line.includes('*RAS_INT_START')){inData=true;continue;}
      if(line.includes('*RAS_INT_END')){break;}
      if(inData&&line.trim()&&!line.trim().startsWith('*')){
        const p=line.trim().split(/\s+/);
        // SmartLab often writes 3 columns: 2theta, intensity, monitor/weight (use first two only).
        if(p.length>=2){
          const x=parseFloat(p[0]),y=parseFloat(p[1]);
          if(!isNaN(x)&&!isNaN(y)){tth.push(x);intensity.push(y);}
        }
      }
    }
    if(!tth.length)return null;
    const maxI=Math.max(...intensity);
    const maxIdx=intensity.indexOf(maxI);
    return {
      name:fname.replace('.ras',''),
      tth,
      intensity,
      maxI,
      peakPos:tth[maxIdx].toFixed(2),
      color:color||'#000',
      tempStart,
      tempEnd,
      timeStart,
      timeEnd
    };
  }

  function loadRasFiles(files,options){
    const opts=Object.assign({
      sortNatural:false,
      onSample:null,
      onComplete:null,
      makeColor:()=>'#000'
    },options||{});
    const rasFiles=[...files].filter(f=>f.name.endsWith('.ras'));
    const sorted=opts.sortNatural?rasFiles.sort((a,b)=>naturalCompareText(a.name,b.name)):rasFiles;
    let pending=sorted.length;
    const parsed=new Array(sorted.length);
    if(!pending){
      if(opts.onComplete)opts.onComplete([]);
      return;
    }
    sorted.forEach((f,fi)=>{
      const r=new FileReader();
      r.onload=ev=>{
        const p=parseRas(ev.target.result,f.name,opts.makeColor(fi));
        if(p){
          p.visible=true;
          p.group='A';
          p.scanRate=null;
          p.rampStartTemp=null;
          parsed[fi]=p;
          if(opts.onSample)opts.onSample(p,fi);
        }
        pending-=1;
        if(pending===0&&opts.onComplete){
          opts.onComplete(parsed.filter(Boolean));
        }
      };
      r.readAsText(f,'latin1');
    });
  }

  window.XrdThermalCommon={
    naturalKey,
    naturalCompareByName,
    parseDateTime,
    parseRas,
    loadRasFiles
  };
})();
