#!/usr/bin/env python3
"""
Calibration Data Analysis Script (WIN-10)

Reads calibration_YYYY-MM-DD.json exported from CalibrationLogger
and generates statistical analysis to guide threshold calibration.

Usage:
    python3 analyze_calibration.py calibration_2026-07-12.json
"""

import json
import sys
from pathlib import Path
from dataclasses import dataclass
from typing import Dict, List, Tuple
from collections import defaultdict
import statistics

@dataclass
class CalibrationSample:
    pose_id: int
    pose_name: str
    person_id: int
    coverage: float
    score: float
    size_ratio: float
    state: str
    distance: str
    camera: str
    mode: str
    notes: str

@dataclass
class GroupStats:
    """Statistics for a group of samples"""
    group_name: str
    sample_count: int
    avg_score: float
    min_score: float
    max_score: float
    std_score: float
    avg_coverage: float
    avg_size_ratio: float
    perfect_count: int
    close_count: int
    far_count: int
    none_count: int
    
    def report(self) -> str:
        return f"""
{self.group_name}:
  Samples: {self.sample_count}
  Score:   avg={self.avg_score:.3f} min={self.min_score:.3f} max={self.max_score:.3f} σ={self.std_score:.3f}
  Coverage: {self.avg_coverage:.3f}
  Size Ratio: {self.avg_size_ratio:.3f}
  States: perfect={self.perfect_count} close={self.close_count} far={self.far_count} none={self.none_count}
"""

class CalibrationAnalyzer:
    def __init__(self, json_file: str):
        self.samples: List[CalibrationSample] = []
        self.load_json(json_file)
    
    def load_json(self, json_file: str):
        """Load calibration data from JSON export"""
        with open(json_file) as f:
            data = json.load(f)
        
        for item in data:
            sample = CalibrationSample(
                pose_id=item.get('poseId', 0),
                pose_name=item.get('poseName', ''),
                person_id=item.get('personId', 0),
                coverage=item.get('coverage', 0.0),
                score=item.get('score', 0.0),
                size_ratio=item.get('sizeRatio', 0.0),
                state=item.get('state', 'none'),
                distance=item.get('distance', ''),
                camera=item.get('camera', ''),
                mode=item.get('mode', ''),
                notes=item.get('notes', '')
            )
            self.samples.append(sample)
        
        print(f"✅ Loaded {len(self.samples)} samples")
    
    def stats_by_group(self, group_by: List[str]) -> Dict[tuple, GroupStats]:
        """Group samples and compute statistics"""
        groups: Dict[tuple, List[CalibrationSample]] = defaultdict(list)
        
        for sample in self.samples:
            key = tuple(getattr(sample, attr) for attr in group_by)
            groups[key].append(sample)
        
        results = {}
        for key, group in groups.items():
            scores = [s.score for s in group]
            coverages = [s.coverage for s in group]
            size_ratios = [s.size_ratio for s in group]
            
            group_name = " | ".join(
                f"{k}={v}" for k, v in zip(group_by, key)
            )
            
            stats = GroupStats(
                group_name=group_name,
                sample_count=len(group),
                avg_score=statistics.mean(scores),
                min_score=min(scores),
                max_score=max(scores),
                std_score=statistics.stdev(scores) if len(scores) > 1 else 0.0,
                avg_coverage=statistics.mean(coverages),
                avg_size_ratio=statistics.mean(size_ratios),
                perfect_count=sum(1 for s in group if s.state == 'perfect'),
                close_count=sum(1 for s in group if s.state == 'close'),
                far_count=sum(1 for s in group if s.state == 'far'),
                none_count=sum(1 for s in group if s.state == 'none')
            )
            results[key] = stats
        
        return results
    
    def analyze_by_pose(self):
        """Analyze data grouped by pose"""
        print("\n" + "="*70)
        print("ANALYSIS BY POSE")
        print("="*70)
        
        stats = self.stats_by_group(['pose_id', 'pose_name'])
        for key, stat in sorted(stats.items()):
            print(stat.report())
    
    def analyze_by_distance(self):
        """Analyze data grouped by distance"""
        print("\n" + "="*70)
        print("ANALYSIS BY DISTANCE")
        print("="*70)
        
        stats = self.stats_by_group(['distance'])
        for key, stat in sorted(stats.items()):
            print(stat.report())
    
    def analyze_by_distance_camera_mode(self):
        """Detailed analysis: distance × camera × mode"""
        print("\n" + "="*70)
        print("DETAILED: DISTANCE × CAMERA × MODE")
        print("="*70)
        
        stats = self.stats_by_group(['distance', 'camera', 'mode'])
        
        # Sort by distance first, then camera, then mode
        distance_order = {'close': 0, 'medium': 1, 'far': 2}
        camera_order = {'front': 0, 'back': 1}
        mode_order = {'full-body': 0, 'close-up': 1}
        
        def sort_key(item):
            key = item[0]
            return (
                distance_order.get(key[0], 999),
                camera_order.get(key[1], 999),
                mode_order.get(key[2], 999)
            )
        
        for key, stat in sorted(stats.items(), key=sort_key):
            print(stat.report())
    
    def check_false_positives(self, threshold: float = 0.85):
        """Find false perfect: high score but not perfect state"""
        print("\n" + "="*70)
        print(f"FALSE PERFECT CHECK (score ≥ {threshold})")
        print("="*70)
        
        false_perfect = [
            s for s in self.samples
            if s.score >= threshold and s.state != 'perfect'
        ]
        
        if false_perfect:
            print(f"⚠️  Found {len(false_perfect)} false perfect cases:")
            for s in false_perfect[:10]:  # Show first 10
                print(f"  Person {s.person_id} | {s.pose_name} | "
                      f"{s.distance} {s.camera} {s.mode} | "
                      f"score={s.score:.3f} state={s.state}")
            if len(false_perfect) > 10:
                print(f"  ... and {len(false_perfect) - 10} more")
        else:
            print(f"✅ No false perfect cases found")
        
        return len(false_perfect)
    
    def check_false_negatives(self, threshold: float = 0.85):
        """Find false far: low score but perfect state"""
        print("\n" + "="*70)
        print(f"FALSE NEGATIVE CHECK (score < {threshold} but state=perfect)")
        print("="*70)
        
        false_negative = [
            s for s in self.samples
            if s.score < threshold and s.state == 'perfect'
        ]
        
        if false_negative:
            print(f"⚠️  Found {len(false_negative)} false negative cases:")
            for s in false_negative[:10]:
                print(f"  Person {s.person_id} | {s.pose_name} | "
                      f"{s.distance} {s.camera} {s.mode} | "
                      f"score={s.score:.3f}")
            if len(false_negative) > 10:
                print(f"  ... and {len(false_negative) - 10} more")
        else:
            print(f"✅ No false negative cases found")
        
        return len(false_negative)
    
    def check_coverage_distribution(self, min_coverage: float = 0.5):
        """Check if coverage is well above minimum threshold"""
        print("\n" + "="*70)
        print(f"COVERAGE DISTRIBUTION (min_coverage = {min_coverage})")
        print("="*70)
        
        below_min = [s for s in self.samples if s.coverage < min_coverage]
        
        coverages = [s.coverage for s in self.samples]
        print(f"Coverage stats:")
        print(f"  Min: {min(coverages):.3f}")
        print(f"  Max: {max(coverages):.3f}")
        print(f"  Avg: {statistics.mean(coverages):.3f}")
        print(f"  Below threshold: {len(below_min)}/{len(self.samples)}")
        
        if below_min:
            print(f"\n⚠️  These poses have coverage < {min_coverage}:")
            for s in below_min[:5]:
                print(f"  {s.pose_name} (person {s.person_id}): {s.coverage:.3f}")
    
    def check_size_ratio_distribution(self, min_ratio: float = 0.55):
        """Check if far/medium distance splits properly at size ratio"""
        print("\n" + "="*70)
        print(f"SIZE RATIO DISTRIBUTION (min_size_ratio = {min_ratio})")
        print("="*70)
        
        ratios_by_distance = defaultdict(list)
        for s in self.samples:
            ratios_by_distance[s.distance].append(s.size_ratio)
        
        for distance in ['close', 'medium', 'far']:
            ratios = ratios_by_distance.get(distance, [])
            if ratios:
                print(f"\n{distance.upper()}:")
                print(f"  Count: {len(ratios)}")
                print(f"  Min: {min(ratios):.3f}, Max: {max(ratios):.3f}, Avg: {statistics.mean(ratios):.3f}")
                below = sum(1 for r in ratios if r < min_ratio)
                print(f"  Below {min_ratio}: {below}/{len(ratios)}")
    
    def recommend_thresholds(self):
        """Generate threshold recommendations based on analysis"""
        print("\n" + "="*70)
        print("THRESHOLD RECOMMENDATIONS")
        print("="*70)
        
        # Current values
        current = {
            'minCoverage': 0.5,
            'minSizeRatio': 0.55,
            'closeThreshold': 0.60,
            'perfectThreshold': 0.85
        }
        
        recommendations = {}
        
        # Check false positives/negatives
        false_pos = len([s for s in self.samples if s.score >= 0.85 and s.state != 'perfect'])
        false_neg = len([s for s in self.samples if s.score < 0.85 and s.state == 'perfect'])
        
        print(f"\nCurrent thresholds:")
        for k, v in current.items():
            print(f"  {k} = {v}")
        
        print(f"\nFalse positive rate (score ≥ 0.85): {false_pos}/{len(self.samples)}")
        print(f"False negative rate (score < 0.85 but perfect): {false_neg}/{len(self.samples)}")
        
        # perfectThreshold recommendation
        if false_pos > len(self.samples) * 0.05:  # > 5% false perfect
            recommendations['perfectThreshold'] = 0.87
            print(f"\n  ⬆️  Raise perfectThreshold to 0.87 (reduce false perfect)")
        elif false_neg > len(self.samples) * 0.05:  # > 5% false negative
            recommendations['perfectThreshold'] = 0.83
            print(f"\n  ⬇️  Lower perfectThreshold to 0.83 (catch more perfect)")
        else:
            recommendations['perfectThreshold'] = 0.85
            print(f"\n  ✅ Keep perfectThreshold at 0.85")
        
        # closeThreshold recommendation (similar logic)
        close_boundary = len([s for s in self.samples if 0.55 <= s.score < 0.65 and s.state == 'close'])
        if close_boundary > len(self.samples) * 0.1:
            print(f"  ℹ️  Consider adjusting closeThreshold (many samples near boundary)")
        
        return recommendations
    
    def run_full_analysis(self):
        """Execute all analysis steps"""
        print("\n" + "="*70)
        print("🔍 POSE MATCHER CALIBRATION ANALYSIS (WIN-10)")
        print("="*70)
        print(f"Dataset: {len(self.samples)} samples")
        
        self.analyze_by_pose()
        self.analyze_by_distance()
        self.analyze_by_distance_camera_mode()
        self.check_false_positives()
        self.check_false_negatives()
        self.check_coverage_distribution()
        self.check_size_ratio_distribution()
        recommendations = self.recommend_thresholds()
        
        print("\n" + "="*70)
        print("SUMMARY & NEXT STEPS")
        print("="*70)
        print("\nRecommended changes:")
        for k, v in recommendations.items():
            print(f"  {k} = {v}")
        print("\n📝 Update casube.ios/CameraAI/ML/PoseMatcher.swift with new values")
        print("🧪 Add XCTests for edge cases discovered")
        print("✔️  Run UAT on real iPhone (front/back)")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 analyze_calibration.py <calibration.json>")
        sys.exit(1)
    
    json_file = sys.argv[1]
    if not Path(json_file).exists():
        print(f"❌ File not found: {json_file}")
        sys.exit(1)
    
    analyzer = CalibrationAnalyzer(json_file)
    analyzer.run_full_analysis()
