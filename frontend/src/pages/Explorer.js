import React, { useState, useEffect } from "react";
import api, { formatApiError } from "@/lib/api";
import { useAuth } from "@/contexts/AuthContext";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { toast } from "sonner";
import { BookOpen, Video, FileText, MessageSquare, Plus, Lock, Send, Trash2, ArrowRight, Sparkles, RefreshCw } from "lucide-react";
import MathText from "@/components/MathText";

export default function Explorer() {
  const { user } = useAuth();
  const isAdmin = user?.role in { admin: 1, superadmin: 1 };
  const isPremium = isAdmin || user?.subscription_active;

  // Active class from user profile (default to "10" if not set)
  const classLevel = user?.class_level || "10";
  const [subject, setSubject] = useState("maths");
  const [topic, setTopic] = useState("Algebra");

  // Content states
  const [notes, setNotes] = useState([]);
  const [videos, setVideos] = useState([]);
  const [tests, setTests] = useState([]);
  const [discussions, setDiscussions] = useState([]);

  // Flashcards state
  const [flashcards, setFlashcards] = useState([]);
  const [flashcardsLocked, setFlashcardsLocked] = useState(false);
  const [activeCardIndex, setActiveCardIndex] = useState(0);
  const [isFlipped, setIsFlipped] = useState(false);

  // New Flashcard form
  const [newFront, setNewFront] = useState("");
  const [newBack, setNewBack] = useState("");
  const [addCardOpen, setAddCardOpen] = useState(false);

  // Detail/Modal states
  const [activeNote, setActiveNote] = useState(null);
  const [activeThread, setActiveThread] = useState(null);
  const [threadReplies, setThreadReplies] = useState([]);
  const [newReplyBody, setNewReplyBody] = useState("");

  // Create thread states
  const [threadTitle, setThreadTitle] = useState("");
  const [threadBody, setThreadBody] = useState("");
  const [createThreadOpen, setCreateThreadOpen] = useState(false);

  // Fetch all contents based on filters
  const fetchData = async () => {
    if (!classLevel) return;
    try {
      // 1. Fetch Notes
      const notesRes = await api.get(`/api/notes?class_level=${classLevel}&subject=${subject}&topic=${topic}`);
      setNotes(notesRes.data.items || []);

      // 2. Fetch Videos
      const videosRes = await api.get(`/api/videos?class_level=${classLevel}`);
      const filteredVideos = (videosRes.data.items || []).filter(
        (v) => v.subject.toLowerCase() === subject.toLowerCase() && (!topic || v.topic?.toLowerCase() === topic.toLowerCase())
      );
      setVideos(filteredVideos);

      // 3. Fetch Tests
      const testsRes = await api.get(`/api/tests?class_level=${classLevel}`);
      const filteredTests = (testsRes.data.items || []).filter(
        (t) => t.subject.toLowerCase() === subject.toLowerCase() && t.is_published
      );
      setTests(filteredTests);

      // 4. Fetch Discussions
      const discRes = await api.get(`/api/discussions?class_level=${classLevel}&subject=${subject}&topic=${topic}`);
      setDiscussions(discRes.data.items || []);

      // 5. Fetch Flashcards
      const fcRes = await api.get(`/api/flashcards?class_level=${classLevel}&subject=${subject}&topic=${topic}`);
      setFlashcardsLocked(fcRes.data.locked);
      setFlashcards(fcRes.data.items || []);
      setActiveCardIndex(0);
      setIsFlipped(false);
    } catch (err) {
      toast.error("Failed to load study explorer contents.");
    }
  };

  useEffect(() => {
    fetchData();
  }, [classLevel, subject, topic]);

  // Load discussion thread details
  const viewThread = async (threadId) => {
    try {
      const res = await api.get(`/api/discussions/${threadId}`);
      setActiveThread(res.data);
      setThreadReplies(res.data.replies || []);
    } catch (err) {
      toast.error("Failed to load thread replies.");
    }
  };

  // Submit doubt reply
  const submitReply = async (e) => {
    e.preventDefault();
    if (!newReplyBody.trim() || !activeThread) return;
    try {
      const res = await api.post(`/api/discussions/${activeThread._id}/reply`, { body: newReplyBody });
      setThreadReplies([...threadReplies, res.data]);
      setNewReplyBody("");
      toast.success("Reply posted!");
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  // Create doubt thread
  const createThread = async (e) => {
    e.preventDefault();
    if (!threadTitle.trim() || !threadBody.trim()) {
      toast.error("Please fill in all fields.");
      return;
    }
    try {
      await api.post("/api/discussions", {
        title: threadTitle,
        body: threadBody,
        class_level: classLevel,
        subject,
        topic,
      });
      toast.success("Doubt posted successfully!");
      setThreadTitle("");
      setThreadBody("");
      setCreateThreadOpen(false);
      fetchData();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  // Create flashcard (admin)
  const addFlashcard = async (e) => {
    e.preventDefault();
    if (!newFront.trim() || !newBack.trim()) {
      toast.error("Please fill in front and back of the card.");
      return;
    }
    try {
      await api.post("/api/flashcards", {
        subject,
        class_level: classLevel,
        topic,
        front: newFront,
        back: newBack,
      });
      toast.success("Flashcard added successfully!");
      setNewFront("");
      setNewBack("");
      setAddCardOpen(false);
      fetchData();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  // Delete flashcard (admin)
  const deleteFc = async (fid, e) => {
    e.stopPropagation();
    if (!window.confirm("Delete this flashcard?")) return;
    try {
      await api.delete(`/api/flashcards/${fid}`);
      toast.success("Flashcard deleted.");
      fetchData();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  // Delete Thread
  const deleteThread = async (tid) => {
    if (!window.confirm("Are you sure you want to delete this thread?")) return;
    try {
      await api.delete(`/api/discussions/${tid}`);
      toast.success("Thread deleted.");
      if (activeThread?._id === tid) setActiveThread(null);
      fetchData();
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  // Delete Reply
  const deleteReply = async (rid) => {
    if (!window.confirm("Delete this reply?")) return;
    try {
      await api.delete(`/api/discussions/${activeThread._id}/reply/${rid}`);
      setThreadReplies(threadReplies.filter((r) => r.reply_id !== rid));
      toast.success("Reply deleted.");
    } catch (err) {
      toast.error(formatApiError(err));
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-5 sm:px-10 py-8">
      {/* Header section */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-[#0F1B4C]/10 pb-6 mb-8">
        <div>
          <div className="text-xs tracking-[0.24em] uppercase text-[#7C3AED] font-semibold">Premium Learning Dashboard</div>
          <h1 className="mt-2 font-serif text-4xl text-[#0F1B4C] font-semibold">Study Explorer</h1>
          <p className="text-slate-500 mt-1 text-sm">Explore notes, flashcards, watch video lessons, attempt mock tests, and resolve doubts in one place.</p>
        </div>

        {/* Filter controls */}
        <div className="flex flex-wrap items-center gap-3 bg-white p-3 rounded-2xl shadow-sm border border-slate-100">
          <div>
            <Select value={subject} onValueChange={setSubject}>
              <SelectTrigger className="w-[140px] rounded-full border-slate-200">
                <SelectValue placeholder="Subject" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="maths">Mathematics</SelectItem>
                <SelectItem value="science" disabled>Science (Coming Soon)</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div>
            <Input
              value={topic}
              onChange={(e) => setTopic(e.target.value)}
              placeholder="Topic/Chapter..."
              className="w-[180px] rounded-full border-slate-200"
            />
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-8">
        {/* Left pane: Topic details summary card */}
        <div className="lg:col-span-1 space-y-4">
          <Card className="p-6 rounded-3xl border-slate-100 bg-[#0F1B4C] text-white shadow-xl relative overflow-hidden">
            <div className="absolute right-0 bottom-0 translate-y-1/4 translate-x-1/4 w-32 h-32 rounded-full bg-gradient-to-tr from-[#7C3AED]/20 to-[#2563EB]/40 blur-xl"></div>
            <div className="text-xs uppercase tracking-wider text-slate-300">Active Topic</div>
            <h2 className="text-2xl font-serif mt-1 font-semibold">{topic || "All Chapters"}</h2>
            <div className="mt-4 space-y-2 text-sm text-slate-300">
              <div className="flex justify-between border-b border-white/10 pb-1">
                <span>Class Level:</span>
                <span className="font-semibold text-white">Class {classLevel}</span>
              </div>
              <div className="flex justify-between border-b border-white/10 pb-1">
                <span>Subject:</span>
                <span className="font-semibold text-white capitalize">{subject}</span>
              </div>
            </div>
          </Card>
        </div>

        {/* Right pane: Unified Explorer Tabs */}
        <div className="lg:col-span-3">
          <Tabs defaultValue="notes" className="w-full">
            <TabsList className="grid grid-cols-5 w-full bg-slate-100/80 p-1 rounded-2xl mb-6">
              <TabsTrigger value="notes" className="rounded-xl flex items-center justify-center gap-1 py-2.5 text-[11px] sm:text-xs md:text-sm"><FileText size={13} /> Notes</TabsTrigger>
              <TabsTrigger value="flashcards" className="rounded-xl flex items-center justify-center gap-1 py-2.5 text-[11px] sm:text-xs md:text-sm"><Sparkles size={13} /> Cards</TabsTrigger>
              <TabsTrigger value="videos" className="rounded-xl flex items-center justify-center gap-1 py-2.5 text-[11px] sm:text-xs md:text-sm"><Video size={13} /> Videos</TabsTrigger>
              <TabsTrigger value="tests" className="rounded-xl flex items-center justify-center gap-1 py-2.5 text-[11px] sm:text-xs md:text-sm"><BookOpen size={13} /> Tests</TabsTrigger>
              <TabsTrigger value="doubts" className="rounded-xl flex items-center justify-center gap-1 py-2.5 text-[11px] sm:text-xs md:text-sm"><MessageSquare size={13} /> Doubts</TabsTrigger>
            </TabsList>

            {/* TAB 1: STUDY NOTES */}
            <TabsContent value="notes" className="space-y-4 outline-none">
              <div className="grid md:grid-cols-2 gap-4">
                {notes.map((note) => (
                  <Card
                    key={note._id}
                    className="p-6 rounded-2xl border-slate-150 shadow-sm hover:shadow-md transition-shadow cursor-pointer flex flex-col justify-between"
                    onClick={() => setActiveNote(note)}
                  >
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-[10px] uppercase font-bold tracking-wider text-[#7C3AED] bg-violet-50 px-2 py-0.5 rounded-full">Note</span>
                        {note.premium_only && (
                          <span className="text-[10px] uppercase font-bold tracking-wider bg-amber-500 text-white px-2 py-0.5 rounded-full flex items-center gap-0.5"><Lock size={10} /> Premium</span>
                        )}
                      </div>
                      <h3 className="font-serif text-lg text-[#0F1B4C] mt-2 font-semibold hover:text-[#2563EB] transition-colors">{note.title}</h3>
                    </div>
                    <div className="mt-4 flex items-center justify-between text-xs text-slate-500 pt-3 border-t border-slate-50">
                      <span>{new Date(note.created_at || Date.now()).toLocaleDateString()}</span>
                      <span className="text-[#2563EB] font-medium flex items-center gap-0.5">Read Note <ArrowRight size={12} /></span>
                    </div>
                  </Card>
                ))}
              </div>
              {notes.length === 0 && (
                <div className="text-center text-slate-500 py-12 bg-slate-50 rounded-2xl border border-dashed border-slate-200">No study notes available for this topic.</div>
              )}
            </TabsContent>

            {/* TAB 2: FLASHCARDS (Premium) */}
            <TabsContent value="flashcards" className="space-y-4 outline-none">
              <div className="flex justify-between items-center pb-2">
                <h3 className="font-serif text-lg text-[#0F1B4C] font-semibold">Flashcards</h3>
                {isAdmin && (
                  <Button className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9] text-xs" onClick={() => setAddCardOpen(true)}><Plus size={14} className="mr-1" /> Add Card</Button>
                )}
              </div>

              {flashcardsLocked ? (
                <div className="text-center py-10 bg-slate-50 rounded-2xl border border-slate-150 p-8 shadow-sm">
                  <div className="w-12 h-12 rounded-full bg-amber-100 text-amber-500 grid place-items-center mx-auto mb-4"><Lock size={20} /></div>
                  <h3 className="font-serif text-lg text-[#0F1B4C] font-semibold">Premium Flashcards Locked</h3>
                  <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">Flashcards help you memorize core terms and formulas rapidly. Upgrade to StudyBook Premium to access them.</p>
                  <a href="/pricing"><Button className="mt-4 rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] text-xs px-6">View Premium Plans</Button></a>
                </div>
              ) : flashcards.length === 0 ? (
                <div className="text-center text-slate-500 py-12 bg-slate-50 rounded-2xl border border-dashed border-slate-200">No flashcards created for this topic yet.</div>
              ) : (
                <div className="flex flex-col items-center gap-6 py-6">
                  {/* Card Deck Wrapper */}
                  <div
                    onClick={() => setIsFlipped(!isFlipped)}
                    className="w-full max-w-md h-64 bg-white border border-slate-200 rounded-3xl p-6 shadow-md hover:shadow-lg cursor-pointer flex flex-col justify-between items-center text-center transition-all relative overflow-hidden select-none"
                  >
                    <div className="absolute top-3 right-3 text-slate-400"><RefreshCw size={14} /></div>
                    <div className="text-[10px] uppercase font-bold tracking-wider text-slate-400">{isFlipped ? "Answer (Back)" : "Question (Front)"}</div>
                    <div className="font-serif text-lg text-[#0F1B4C] font-semibold max-w-xs leading-relaxed">
                      {isFlipped ? (
                        <MathText text={flashcards[activeCardIndex].back} />
                      ) : (
                        <MathText text={flashcards[activeCardIndex].front} />
                      )}
                    </div>
                    <div className="text-xs text-slate-400">Tap card to flip</div>
                    {isAdmin && (
                      <button
                        onClick={(e) => deleteFc(flashcards[activeCardIndex]._id, e)}
                        className="absolute bottom-3 right-3 text-red-500 hover:text-red-600 h-8 w-8 grid place-items-center rounded-full hover:bg-slate-50"
                      >
                        <Trash2 size={14} />
                      </button>
                    )}
                  </div>

                  {/* Navigation controls */}
                  <div className="flex items-center gap-4 text-sm font-medium">
                    <Button
                      variant="outline"
                      className="rounded-full h-9"
                      onClick={() => {
                        setIsFlipped(false);
                        setActiveCardIndex((activeCardIndex - 1 + flashcards.length) % flashcards.length);
                      }}
                    >
                      Prev
                    </Button>
                    <span className="text-[#0F1B4C] font-mono">
                      {activeCardIndex + 1} of {flashcards.length}
                    </span>
                    <Button
                      className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] h-9"
                      onClick={() => {
                        setIsFlipped(false);
                        setActiveCardIndex((activeCardIndex + 1) % flashcards.length);
                      }}
                    >
                      Next
                    </Button>
                  </div>
                </div>
              )}
            </TabsContent>

            {/* TAB 3: VIDEOS */}
            <TabsContent value="videos" className="space-y-4 outline-none">
              <div className="grid md:grid-cols-2 gap-5">
                {videos.map((vid) => (
                  <Card key={vid._id} className="rounded-2xl border-slate-200 overflow-hidden shadow-sm hover:shadow-md transition-all">
                    <div className="relative aspect-video bg-slate-900 flex items-center justify-center">
                      <img src={vid.thumbnail_url || "https://images.unsplash.com/photo-1509228468518-180dd4864904"} alt="" className="w-full h-full object-cover opacity-80" />
                      <a href={vid.url} target="_blank" rel="noreferrer" className="absolute w-12 h-12 rounded-full bg-white/95 text-[#0F1B4C] shadow-lg grid place-items-center hover:scale-105 transition-transform"><Video size={20} className="fill-[#0F1B4C] text-[#0F1B4C]" /></a>
                      {vid.premium_only && (
                        <span className="absolute top-2 right-2 text-[10px] uppercase font-bold bg-amber-500 text-white px-2 py-0.5 rounded-full flex items-center gap-0.5"><Lock size={10} /> Premium</span>
                      )}
                    </div>
                    <div className="p-5">
                      <h4 className="font-serif text-base text-[#0F1B4C] font-semibold line-clamp-1">{vid.title}</h4>
                      <p className="text-xs text-slate-500 mt-1 line-clamp-2">{vid.description}</p>
                    </div>
                  </Card>
                ))}
              </div>
              {videos.length === 0 && (
                <div className="text-center text-slate-500 py-12 bg-slate-50 rounded-2xl border border-dashed border-slate-200">No video lessons available for this topic.</div>
              )}
            </TabsContent>

            {/* TAB 4: TESTS */}
            <TabsContent value="tests" className="space-y-4 outline-none">
              <div className="grid md:grid-cols-2 gap-4">
                {tests.map((test) => (
                  <Card key={test._id} className="p-6 rounded-2xl border-slate-200 shadow-sm flex flex-col justify-between">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="text-[10px] uppercase font-bold tracking-wider bg-blue-50 text-blue-600 px-2 py-0.5 rounded-full">{test.test_type} Test</span>
                        {test.premium_only && (
                          <span className="text-[10px] uppercase font-bold tracking-wider bg-amber-500 text-white px-2 py-0.5 rounded-full flex items-center gap-0.5"><Lock size={10} /> Premium</span>
                        )}
                      </div>
                      <h3 className="font-serif text-lg text-[#0F1B4C] mt-2 font-semibold">{test.title}</h3>
                      <p className="text-xs text-slate-500 mt-1 line-clamp-2">{test.description}</p>
                      <div className="mt-3 flex items-center gap-4 text-xs text-slate-500">
                        <span>Duration: {test.duration_minutes}m</span>
                        <span>Questions: {test.question_ids?.length || 0}</span>
                      </div>
                    </div>
                    <div className="mt-4 pt-3 border-t border-slate-50 flex items-center justify-end">
                      {test.premium_only && !isPremium ? (
                        <Button className="rounded-full bg-amber-500 hover:bg-amber-600 text-xs px-4" onClick={() => toast.error("Premium upgrade required to unlock tests.")}><Lock size={12} className="mr-1" /> Locked</Button>
                      ) : (
                        <a href={`/tests/${test._id}/live`}><Button className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] text-xs px-4">Start Test</Button></a>
                      )}
                    </div>
                  </Card>
                ))}
              </div>
              {tests.length === 0 && (
                <div className="text-center text-slate-500 py-12 bg-slate-50 rounded-2xl border border-dashed border-slate-200">No mock tests published for this subject.</div>
              )}
            </TabsContent>

            {/* TAB 5: DOUBTS DISCUSSION FORUM */}
            <TabsContent value="doubts" className="space-y-4 outline-none">
              <div className="flex justify-between items-center pb-2">
                <h3 className="font-serif text-lg text-[#0F1B4C] font-semibold">Doubts Discussion Board</h3>
                <Button className="rounded-full bg-[#7C3AED] hover:bg-[#6D28D9] text-xs" onClick={() => setCreateThreadOpen(true)}><Plus size={14} className="mr-1" /> Ask a Doubt</Button>
              </div>

              <div className="space-y-3">
                {discussions.map((t) => (
                  <Card key={t._id} className="p-5 rounded-2xl border-slate-155 shadow-sm hover:shadow-md transition-shadow">
                    <div className="flex items-start justify-between gap-4">
                      <div className="cursor-pointer flex-1" onClick={() => viewThread(t._id)}>
                        <h4 className="font-serif text-base text-[#0F1B4C] font-semibold hover:text-[#2563EB]">{t.title}</h4>
                        <p className="text-slate-600 text-xs mt-1 line-clamp-2">{t.body}</p>
                        <div className="mt-3 flex items-center gap-4 text-[10px] text-slate-400">
                          <span>Posted by: {t.user_name} ({t.user_role})</span>
                          <span>Replies: {t.replies_count}</span>
                          <span>{new Date(t.created_at || Date.now()).toLocaleString()}</span>
                        </div>
                      </div>
                      {(str(t.user_id) === str(user?._id) || isAdmin) && (
                        <Button variant="ghost" size="icon" onClick={() => deleteThread(t._id)} className="text-red-500 hover:text-red-600 shrink-0"><Trash2 size={15} /></Button>
                      )}
                    </div>
                  </Card>
                ))}
              </div>
              {discussions.length === 0 && (
                <div className="text-center text-slate-500 py-12 bg-slate-50 rounded-2xl border border-dashed border-slate-200">No doubts posted yet. Be the first to ask!</div>
              )}
            </TabsContent>
          </Tabs>
        </div>
      </div>

      {/* DETAIL MODAL: VIEW NOTE */}
      <Dialog open={!!activeNote} onOpenChange={() => setActiveNote(null)}>
        <DialogContent className="max-w-3xl max-h-[85vh] overflow-y-auto rounded-3xl p-6">
          {activeNote && (
            <div>
              <DialogHeader className="border-b border-slate-100 pb-4 mb-4">
                <DialogTitle className="font-serif text-2xl text-[#0F1B4C]">{activeNote.title}</DialogTitle>
                <div className="text-xs text-slate-500 mt-1 flex items-center gap-2">
                  <span className="capitalize">{activeNote.subject}</span> · <span>Class {activeNote.class_level}</span> · <span>Topic: {activeNote.topic}</span>
                </div>
              </DialogHeader>
              {activeNote.premium_only && !isPremium ? (
                <div className="text-center py-10 bg-slate-50 rounded-2xl border border-slate-150 p-8">
                  <div className="w-12 h-12 rounded-full bg-amber-100 text-amber-500 grid place-items-center mx-auto mb-4"><Lock size={20} /></div>
                  <h3 className="font-serif text-lg text-[#0F1B4C] font-semibold">Premium Content Locked</h3>
                  <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">This study note is exclusively available for premium members. Upgrade to StudyBook Premium to access premium notes, video lessons, and unlocked tests.</p>
                  <a href="/pricing"><Button className="mt-4 rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] text-xs px-6">View Premium Plans</Button></a>
                </div>
              ) : (
                <div className="prose prose-slate max-w-none text-slate-700 leading-relaxed text-sm py-2">
                  <MathText text={activeNote.content} />
                </div>
              )}
            </div>
          )}
        </DialogContent>
      </Dialog>

      {/* MODAL: VIEW DISCUSSION THREAD */}
      <Dialog open={!!activeThread} onOpenChange={() => setActiveThread(null)}>
        <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto rounded-3xl p-6 flex flex-col">
          {activeThread && (
            <div className="flex-1 flex flex-col justify-between">
              <div>
                <DialogHeader className="border-b border-slate-100 pb-4">
                  <DialogTitle className="font-serif text-xl text-[#0F1B4C]">{activeThread.title}</DialogTitle>
                  <div className="text-xs text-slate-400 mt-1">Posted by {activeThread.user_name} ({activeThread.user_role})</div>
                </DialogHeader>

                <div className="py-4 text-slate-700 text-sm border-b border-slate-100 bg-slate-50 p-4 rounded-2xl my-3">{activeThread.body}</div>

                <div className="space-y-3 max-h-[250px] overflow-y-auto pr-1">
                  <div className="text-xs font-semibold text-slate-500 uppercase tracking-wider">Answers & Discussion</div>
                  {threadReplies.map((r) => (
                    <div key={r.reply_id} className="p-3 bg-slate-50/50 border border-slate-100 rounded-xl flex items-start justify-between gap-3 text-xs">
                      <div className="flex-1">
                        <div className="flex items-center gap-2 text-slate-400">
                          <span className="font-semibold text-slate-600">{r.user_name} ({r.role})</span>
                          <span>·</span>
                          <span>{new Date(r.created_at).toLocaleString()}</span>
                        </div>
                        <div className="mt-1 text-slate-700 font-serif whitespace-pre-wrap"><MathText text={r.body} /></div>
                      </div>
                      {(str(r.user_id) === str(user?._id) || isAdmin) && (
                        <Button variant="ghost" size="icon" onClick={() => deleteReply(r.reply_id)} className="text-red-500 hover:bg-slate-100 hover:text-red-600 shrink-0 h-7 w-7"><Trash2 size={12} /></Button>
                      )}
                    </div>
                  ))}
                  {threadReplies.length === 0 && (
                    <div className="text-center text-slate-400 py-6 text-xs bg-slate-50/20 rounded-xl border border-slate-100">No replies yet. Help solve this doubt!</div>
                  )}
                </div>
              </div>

              {/* Reply Form */}
              <form onSubmit={submitReply} className="mt-4 pt-3 border-t border-slate-100 flex gap-2">
                <Input
                  value={newReplyBody}
                  onChange={(e) => setNewReplyBody(e.target.value)}
                  placeholder="Type your answer... (supports inline $...$ LaTeX)"
                  className="rounded-full border-slate-200 text-xs"
                />
                <Button type="submit" size="icon" className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB] shrink-0"><Send size={14} /></Button>
              </form>
            </div>
          )}
        </DialogContent>
      </Dialog>

      {/* MODAL: POST A DOUBT */}
      <Dialog open={createThreadOpen} onOpenChange={setCreateThreadOpen}>
        <DialogContent className="max-w-md rounded-3xl p-6">
          <DialogHeader><DialogTitle className="font-serif text-lg text-[#0F1B4C]">Ask a Doubt</DialogTitle></DialogHeader>
          <form onSubmit={createThread} className="space-y-4 mt-2">
            <div>
              <Label>Doubt Title</Label>
              <Input
                value={threadTitle}
                onChange={(e) => setThreadTitle(e.target.value)}
                placeholder="Briefly state your question..."
                className="mt-1 border-slate-200"
              />
            </div>
            <div>
              <Label>Detailed Description</Label>
              <textarea
                rows={4}
                value={threadBody}
                onChange={(e) => setThreadBody(e.target.value)}
                placeholder="Explain what you need help with (supports $...$ for LaTeX equations)..."
                className="w-full mt-1 rounded-md border border-slate-200 p-3 text-sm focus:outline-none focus:border-slate-400"
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <Button type="button" variant="outline" className="rounded-full" onClick={() => setCreateThreadOpen(false)}>Cancel</Button>
              <Button type="submit" className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]">Post Doubt</Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>

      {/* ADMIN DIALOG: ADD FLASHCARD */}
      <Dialog open={addCardOpen} onOpenChange={setAddCardOpen}>
        <DialogContent className="max-w-md rounded-3xl p-6">
          <DialogHeader><DialogTitle className="font-serif text-lg text-[#0F1B4C]">Create New Flashcard</DialogTitle></DialogHeader>
          <form onSubmit={addFlashcard} className="space-y-4 mt-2">
            <div>
              <Label>Question / Term (Front of Card)</Label>
              <Input
                value={newFront}
                onChange={(e) => setNewFront(e.target.value)}
                placeholder="e.g. What is the value of sin(45)?"
                className="mt-1 border-slate-200"
              />
            </div>
            <div>
              <Label>Definition / Answer (Back of Card)</Label>
              <textarea
                rows={4}
                value={newBack}
                onChange={(e) => setNewBack(e.target.value)}
                placeholder="e.g. $1 / \sqrt{2}$"
                className="w-full mt-1 rounded-md border border-slate-200 p-3 text-sm focus:outline-none focus:border-slate-400"
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <Button type="button" variant="outline" className="rounded-full" onClick={() => setAddCardOpen(false)}>Cancel</Button>
              <Button type="submit" className="rounded-full bg-[#0F1B4C] hover:bg-[#2563EB]">Save Flashcard</Button>
            </div>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}

// Utility helper to cast user IDs safely
function str(x) {
  if (!x) return "";
  return typeof x === "object" ? String(x._id || x) : String(x);
}
