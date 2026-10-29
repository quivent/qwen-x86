"""Reference/native screen captures through tmux's real terminal emulator.
Development-only pyte/Pillow render the captured cell grid to reviewable PNGs.
"""
import hashlib,json,os,pathlib,re,shlex,subprocess,tempfile,time
ROOT=pathlib.Path(__file__).resolve().parents[1]
def terminal_screen(columns,rows):
 """Reconstruct captured tmux cells without pyte dropping VS15 text runs.

 pyte0.8.2 stops an entire draw run on a zero-width variation selector. tmux
 legitimately coalesces same-color text around that selector; replay by full
 graphemes preserves the terminal's text and cell positions instead.
 """
 import pyte,regex
 from wcwidth import wcswidth
 from pyte import modes
 class GraphemeScreen(pyte.Screen):
  def draw(self,data):
   data=data.translate(self.g1_charset if self.charset else self.g0_charset)
   for cluster in regex.findall(r'\X',data):
    width=wcswidth(cluster)
    if width<0:continue
    if width==0:
     if self.cursor.x:
      x=min(self.cursor.x,self.columns)-1
      while x and not self.buffer[self.cursor.y][x].data:x-=1
      old=self.buffer[self.cursor.y][x]
      self.buffer[self.cursor.y][x]=old._replace(data=old.data+cluster)
     continue
    if self.cursor.x>=self.columns or self.cursor.x+width>self.columns:
     if modes.DECAWM in self.mode:self.carriage_return();self.linefeed()
     else:self.cursor.x=max(0,self.columns-width)
    if modes.IRM in self.mode:self.insert_characters(width)
    line=self.buffer[self.cursor.y];line[self.cursor.x]=self.cursor.attrs._replace(data=cluster)
    for extra in range(1,width):
     if self.cursor.x+extra<self.columns:line[self.cursor.x+extra]=self.cursor.attrs._replace(data='')
    self.cursor.x=min(self.columns,self.cursor.x+width);self.dirty.add(self.cursor.y)
 return GraphemeScreen(columns,rows)

class Session:
 def __init__(self,client,workspace,home,url,columns=100,rows=30,save_session=False):
  native_binary=pathlib.Path(os.environ.get('QWEN_UI_NATIVE_BINARY',str(ROOT/'qwen-x86')))
  self.binary_sha256=hashlib.sha256(native_binary.read_bytes()).hexdigest() if client=='native' else None
  self.client=client;self.columns=columns;self.rows=rows;self.socket='qwen-ui-'+str(os.getpid())+'-'+str(time.time_ns());self.target='capture'
  env={'HOME':str(home),'PATH':os.environ['PATH'],'TERM':'xterm-256color','COLORTERM':'truecolor','OPENAI_API_KEY':'ui-fixture-only','QWEN_API_KEY':'ui-fixture-only','QWEN_HOME':str(home/'.qwen'),'NO_PROXY':'localhost,127.0.0.1','QWEN_CODE_DISABLE_TELEMETRY':'1','QWEN_CODE_SKIP_UPDATE_CHECK_ONCE':'true','LANG':'C.UTF-8'}
  if client=='reference':
   qhome=home/'.qwen';qhome.mkdir(exist_ok=True)
   (qhome/'settings.json').write_text(json.dumps({'general':{'enableAutoUpdate':False},'telemetry':{'enabled':False}}))
   command=[str(pathlib.Path.home()/'.local/bin/qwen'),'--auth-type','openai','--openai-base-url',url,'--openai-api-key','ui-fixture-only','--model','bench-model','--approval-mode','default','--telemetry=false']
  else:
   command=[str(native_binary),'--base-url',url,'--model','bench-model','--cwd',str(workspace)]
   if not save_session:command.append('--no-save')
  invocation=['env','-i',*[key+'='+value for key,value in env.items()],*command]
  self.run('new-session','-d','-s',self.target,'-x',str(columns),'-y',str(rows),'-c',str(workspace),shlex.join(invocation))
  self.run('set-option','-g','status','off')
  self.run('set-option','-g','history-limit','10000')
 def run(self,*args):return subprocess.check_output(['tmux','-L',self.socket,*args],text=True)
 def text(self,styled=False):return self.run('capture-pane','-p',*(['-e'] if styled else []),'-t',self.target)
 def wait(self,needle,timeout=25):
  deadline=time.monotonic()+timeout
  while time.monotonic()<deadline:
   text=self.text()
   if needle.lower() in text.lower():return text
   time.sleep(.1)
  raise RuntimeError(self.client+' never displayed '+repr(needle)+'\n'+self.text())
 def literal(self,text):
  self.run('set-buffer','-b','fixture',text)
  self.run('paste-buffer','-p','-b','fixture','-t',self.target)
  time.sleep(.2)
 def key(self,*keys):
  self.run('send-keys','-t',self.target,*keys)
  time.sleep(.15)
 def resize(self,cols,rows):
  self.columns,self.rows=cols,rows;self.run('resize-window','-t',self.target,'-x',str(cols),'-y',str(rows));time.sleep(.2)
 def save(self,path):
  import pyte
  from PIL import Image,ImageDraw,ImageFont
  path=pathlib.Path(path);path.parent.mkdir(parents=True,exist_ok=True)
  raw=self.text(styled=True);plain=self.text();path.with_suffix('.ansi').write_text(raw);path.with_suffix('.txt').write_text(plain)
  cols,rows=map(int,self.run('display-message','-p','-t',self.target,'#{pane_width} #{pane_height}').split())
  screen=terminal_screen(cols,rows);stream=pyte.Stream(screen);stream.feed(raw.removesuffix('\n').replace('\n','\r\n'))
  cells=[]
  for row in range(rows):
   cells.append([{'text':screen.buffer[row][col].data,'fg':screen.buffer[row][col].fg,'bg':screen.buffer[row][col].bg,'bold':screen.buffer[row][col].bold,'italic':screen.buffer[row][col].italics,'underline':screen.buffer[row][col].underscore,'reverse':screen.buffer[row][col].reverse} for col in range(cols)])
  metadata={'binary_sha256':self.binary_sha256,'client':self.client,'columns':cols,'rows':rows,'cursor_visible':self.run('display-message','-p','-t',self.target,'#{cursor_flag}').strip(),'cursor':self.run('display-message','-p','-t',self.target,'#{cursor_x} #{cursor_y}').strip(),'cells':cells}
  path.with_suffix('.json').write_text(json.dumps(metadata,ensure_ascii=False,separators=(',',':'))+'\n')
  render_capture(metadata,path)
  return metadata
 def close(self):subprocess.run(['tmux','-L',self.socket,'kill-server'],capture_output=True)


def render_capture(metadata,path):
 """Render recorded cells, with symbol fallbacks for terminal status glyphs."""
 from PIL import Image,ImageDraw,ImageFont
 cells=metadata['cells'];cols=metadata['columns'];rows=metadata['rows'];path=pathlib.Path(path)
 normal=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',16);bold=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf',16);symbols=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16);pause=ImageFont.truetype('/usr/share/fonts/truetype/freefont/FreeSans.ttf',16);cjk=ImageFont.truetype('/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc',16)
 width,height=10,21;image=Image.new('RGB',(cols*width,rows*height),'#1e1e2e');draw=ImageDraw.Draw(image)
 colors={'black':'#45475a','red':'#f38ba8','green':'#a6e3a1','brown':'#f9e2af','blue':'#89b4fa','magenta':'#cba6f7','cyan':'#89dceb','white':'#cdd6f4'}
 def color(value,default):return '#'+value if re.fullmatch('[a-fA-F0-9]{6}',value) else colors.get(value,default)
 for row,line in enumerate(cells):
  for col,cell in enumerate(line):
   fg=color(cell['fg'],'#cdd6f4');bg=color(cell['bg'],'#1e1e2e')
   if cell['reverse']:fg,bg=bg,fg
   x,y=col*width,row*height;draw.rectangle((x,y,x+width-1,y+height-1),fill=bg)
 for row,line in enumerate(cells):
  for col,cell in enumerate(line):
   fg=color(cell['fg'],'#cdd6f4');bg=color(cell['bg'],'#1e1e2e')
   if cell['reverse']:fg,bg=bg,fg
   x,y=col*width,row*height
   text=cell['text']
   font=pause if '\u23f8' in text else symbols if any(0x2800<=ord(ch)<=0x28ff for ch in text) else cjk if any(0x2e80<=ord(ch)<=0x9fff for ch in text) else bold if cell['bold'] else normal
   draw.text((x,y+1),text,font=font,fill=fg)
   if cell['underline']:draw.line((x,y+height-2,x+width-1,y+height-2),fill=fg)
 image.save(path.with_suffix('.png'))
