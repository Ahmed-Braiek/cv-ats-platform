import assert from "node:assert/strict";
import test from "node:test";
import {documentReadiness, evaluateV2, EVALUATOR_VERSION} from "./scoring.ts";

const cvText = [
  "SOFTWARE DEVELOPER", "Contact email@example.test, telephone 555 0100.",
  "EXPERIENCE", "2021 - Present Freelance full stack development.",
  "Managed complete project lifecycles from requirements gathering and UI/UX",
  "prototyping through development, testing and cloud deployment.",
  "Strong client communication and delivered 30 projects for 20 clients.",
  "Built data dashboards with reporting features, ERP applications and SEO tools.",
  "EDUCATION", "Information Systems Development degree.",
  "CERTIFICATIONS", "Google Digital Marketing certificate.",
  "SKILLS", "React, Flutter, SEO, UI/UX Design, data reporting.",
  "More projects, examples and documented achievements with clients around the world."
].join(" ");
const cv = {
  candidate: {
    name:"Sample Candidate",email:"sample@example.test",phone:"555 0100",
    skills:["React","Flutter","SEO","UI/UX Design"],
    experience:[{title:"Software Developer",dates:"2021 - Present"},{title:"ML developer",dates:"2022 - 2024"}],
    education:[{degree:"Information Systems Development"}],
  },
  sections:{skills:true,experience:true,education:true,standard_headings:true,selectable_text:true},
  document:{raw_text:cvText, page_count:3,layout_risks:[]},
};
const posting = [
  "Marketing Coordinator role",
  "Plan and publish social media posts, email newsletters, and blog content.",
  "Coordinate promotional events, webinars, and partner campaigns.",
  "Strong written and verbal communication skills with close attention to detail.",
  "Familiarity with analytics tools (e.g., Google Analytics) and marketing or CMS platforms.",
  "Experience in marketing coordination, content creation, or campaign execution.",
  "Preferred: Experience using CRM tools (e.g., HubSpot, Salesforce) to track lead handoffs."
].join("\n");
const req=(id,text,source_quote,importance,category,status,evidence_quote="",explanation="")=>({
 id,text,source_quote,importance,category,status,evidence_quote,explanation
});
const job = {role_title:"Marketing Coordinator",requirements:[
  req("R1","Social media and newsletter publication",
    "Plan and publish social media posts, email newsletters, and blog content.",
    "required","responsibility","missing"),
  req("R2","Event and campaign coordination",
    "Coordinate promotional events, webinars, and partner campaigns.",
    "required","responsibility","transferable",
    "Managed complete project lifecycles from requirements gathering and UI/UX"),
  req("R3","Clear written and verbal communication",
    "Strong written and verbal communication skills with close attention to detail.",
    "required","soft_skill","direct","Strong client communication"),
  req("R4","Google Analytics",
    "Familiarity with analytics tools (e.g., Google Analytics) and marketing or CMS platforms.",
    "required","tool","transferable","Built data dashboards with reporting features"),
  req("R5","Marketing coordination tenure",
    "Experience in marketing coordination, content creation, or campaign execution.",
    "required","experience","missing"),
  req("R6","HubSpot or Salesforce",
    "Preferred: Experience using CRM tools (e.g., HubSpot, Salesforce) to track lead handoffs.",
    "preferred","tool","missing"),
]};

test("document readiness measures more than section presence and doesn't assume perfect",()=>{
 const result=documentReadiness(cv);
 assert.equal(result.rubric.version,EVALUATOR_VERSION);
 assert.ok(result.overall>65);
 assert.ok(result.overall<100);
 assert.equal(result.rubric.checks.length,7);
});
test("marketing vs software CV recognizes direct, transferable, missing separately",()=>{
 const result=evaluateV2(cv,job,posting);
 assert.ok(result.match.overall>0,JSON.stringify(result.match));
 assert.ok(result.match.overall<70);
 assert.equal(result.match.rubric.summary.direct,1);
 assert.equal(result.match.rubric.summary.transferable,2);
 assert.equal(result.match.rubric.summary.missing,3);
 assert.equal(result.match.rubric.requirements.length,6);
 assert.ok(result.recommendations.some(x=>x.category==="transferable"));
 assert.ok(result.recommendations.some(x=>x.category==="job_gap"));
});
test("fabricated CV quote never earns direct or partial match",()=>{
 const manipulated=structuredClone(job);
 manipulated.requirements[0].status="direct";
 manipulated.requirements[0].evidence_quote="Ran many paid social media campaigns on Facebook";
 const r=evaluateV2(cv,manipulated,posting);
 assert.equal(r.match.rubric.requirements[0].status,"uncertain");
 assert.equal(r.match.rubric.requirements[0].score,0);
});
test("criterion with invented job source is dropped",()=>{
 const manipulated=structuredClone(job);
 manipulated.requirements.push(req("R99","Cybersecurity PhD required",
   "PhD in cybersecurity is absolutely mandatory","required","education","missing"));
 const r=evaluateV2(cv,manipulated,posting);
 assert.equal(r.match.rubric.summary.total,6);
});
test("a direct named software claim must include the named platform",()=>{
 const manipulated=structuredClone(job);
 manipulated.requirements[3].status="direct";
 const r=evaluateV2(cv,manipulated,posting);
 assert.equal(r.match.rubric.requirements[3].status,"transferable");
});
test("empty or unrelated requirement extraction is not silently scored zero",()=>{
 assert.throws(()=>evaluateV2(cv,{requirements:[]},posting),/job_requirements_not_grounded/);
});
