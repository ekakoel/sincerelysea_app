import 'package:flutter/material.dart';
import 'package:sincerelysea/models/product_review.dart';
import 'package:sincerelysea/services/review_service.dart';

class ReviewEditorScreen extends StatefulWidget {
  const ReviewEditorScreen({
    super.key,
    required this.productId,
    this.existingReview,
  });

  final String productId;
  final ProductReview? existingReview;

  @override
  State<ReviewEditorScreen> createState() => _ReviewEditorScreenState();
}

class _ReviewEditorScreenState extends State<ReviewEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ReviewService _reviewService = ReviewService();
  late final TextEditingController _reviewController;
  late int _rating;
  bool _submitting = false;

  bool get _editing => widget.existingReview != null;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingReview?.rating ?? 0;
    _reviewController = TextEditingController(
      text: widget.existingReview?.reviewText ?? '',
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Review' : 'Write a Review')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              const Text(
                'Your rating',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: _rating == 0
                    ? 'No rating selected'
                    : '$_rating out of 5 stars selected',
                child: Row(
                  children: List<Widget>.generate(5, (int index) {
                    final int value = index + 1;
                    return IconButton(
                      tooltip:
                          value.toString() + (value == 1 ? ' star' : ' stars'),
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _rating = value),
                      icon: Icon(
                        value <= _rating ? Icons.star : Icons.star_border,
                        color: Colors.amber.shade700,
                        size: 32,
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _reviewController,
                enabled: !_submitting,
                minLines: 4,
                maxLines: 8,
                maxLength: ReviewService.maxReviewLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Review',
                  hintText: 'Share your experience with this product',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  final String text = value?.trim() ?? '';
                  if (_rating < 1 || _rating > 5) {
                    return 'Choose a rating from 1 to 5.';
                  }
                  if (text.length < 2) {
                    return 'Write at least 2 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_editing ? 'Save Review' : 'Submit Review'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _submitting = true);
    try {
      if (_editing) {
        await _reviewService.updateReview(
          productId: widget.productId,
          rating: _rating,
          reviewText: _reviewController.text,
        );
      } else {
        await _reviewService.createReview(
          productId: widget.productId,
          rating: _rating,
          reviewText: _reviewController.text,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your review. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
