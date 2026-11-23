import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluate, normalizeTerms } from '../src/scoring.mjs';

test('deduplicates and normalizes skill terms', () => {
 assert.deepEqual(normalizeTerms(['Flutter',' flutter ','NODE.JS','']),['flutter','node.js']);
});
test('ATS and match remain separate dimensions', () => {
 const actual=evaluate({
   candidate:{email:'x@example.test',skills:['Flutter','Node.js'],experience:[{title:'Intern'}],education:[{school:'Test'}]},
   sections:{skills:true,experience:true,education:true,standard_headings:true,selectable_text:true}
 },{required_skills:['Flutter','Python'],preferred_skills:['Node.js']});
 assert.equal(actual.ats.overall,100);
 assert.equal(actual.match.overall,60);
 assert.deepEqual(actual.match.rubric.missing_required,['python']);
});
test('insufficient job evidence never produces a fake perfect match',()=>{
 const actual=evaluate({candidate:{skills:[]},sections:{}},{required_skills:[],preferred_skills:[]});
 assert.equal(actual.match.overall,null);
});
test('recommendations do not tell users to fabricate skills',()=>{
 const actual=evaluate({candidate:{skills:[]},sections:{}},{required_skills:['Rust'],preferred_skills:[]});
 assert.match(actual.recommendations.find(r=>r.category==='matching').message,/Only mention/);
});
